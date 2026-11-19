//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import XCTest
import Combine
import OctopusDependencyInjection
import OctopusRemoteClient
import OctopusGrpcModels
import SwiftProtobuf
@testable import OctopusCore

class SSOConnectionTests: XCTestCase {
    private var injector: Injector!
    private var mockUserService: MockUserService!
    // Built on first use, so that a test can make the secured storage unreadable before the session is read.
    private lazy var userDataStorage: UserDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
    private var userProfileDatabase: CurrentUserProfileDatabase!
    private var userConfigDatabase: UserConfigDatabase!
    private var storage = [AnyCancellable]()
    /// Stands for the device being unlocked or the app coming back.
    private var sessionReadTrigger: PassthroughSubject<Void, Never>!
    private let connectionMode = ConnectionMode.sso(
        .init(appManagedFields: [], loginRequired: { }, modifyUser: { _ in }))
    /// The fields the host app manages, read when the profile repository is first built: set it before.
    private var appManagedFields: Set<ConnectionMode.SSOConfiguration.ProfileField> = []

    override func setUp() {
        let sessionReadTrigger = PassthroughSubject<Void, Never>()
        self.sessionReadTrigger = sessionReadTrigger
        injector = Injector()
        injector.register { _ in try! ModelCoreDataStack(inRam: true) }
        injector.register { _ in try! ConfigCoreDataStack(inRam: true) }
        injector.register { CurrentUserProfileDatabase(injector: $0) }
        injector.register { [unowned self] in
            ProfileRepositoryDefault(appManagedFields: appManagedFields, injector: $0)
        }
        injector.registerMocks(.remoteClient, .securedStorage, .networkMonitor,
                               .userProfileFetchMonitor, .blockedUserIdsProvider, .appStateMonitor, .communityClosure)
        injector.register {
            UserDataStorage(injector: $0, sessionReadTriggers: sessionReadTrigger.eraseToAnyPublisher())
        }
        injector.register { AuthenticatedCallProviderDefault(injector: $0) }
        injector.register { PublicProfileDatabase(injector: $0) }
        injector.register { _ in Validators(appManagedFields: []) }
        injector.register { PostFeedsStore(injector: $0) }
        injector.register { CommentFeedsStore(injector: $0) }
        injector.register { ReplyFeedsStore(injector: $0) }
        injector.register { RepliesDatabase(injector: $0) }
        injector.register { CommentsDatabase(injector: $0) }
        injector.register { PostsDatabase(injector: $0) }
        injector.register { FeedItemInfosDatabase(injector: $0) }
        injector.register { ClientUserProvider(injector: $0) }
        injector.register { ClientUserProfileDatabase(injector: $0) }
        injector.register { UserConfigDatabase(injector: $0) }
        injector.register { CommunityConfigDatabase(injector: $0) }
        injector.register { ConfigRepositoryDefault(injector: $0) }
        injector.register { [unowned self] in ClientUserProfileMerger(appManagedFields: appManagedFields, injector: $0) }
        injector.register { FrictionlessProfileMigrator(injector: $0) }
        injector.register { GamificationRepository(injector: $0) }
        injector.register { ToastsRepository(injector: $0) }
        injector.register { SdkEventsEmitter(injector: $0) }

        mockUserService = (injector.getInjected(identifiedBy: Injected.remoteClient)
            .userService as! MockUserService)

        userProfileDatabase = injector.getInjected(identifiedBy: Injected.currentUserProfileDatabase)
        userConfigDatabase = injector.getInjected(identifiedBy: Injected.userConfigDatabase)
    }

    func testDefaultStateIsNotConnectedWhenNothingIsPresent() async throws {
        // Precondition: no client user data, no user id, no profile in db
        try await setupWithNonConnectedWithoutErrorState()

        let connectionRepository = SSOConnectionRepository(connectionMode: connectionMode, injector: injector)
        switch connectionRepository.connectionState {
        case .notConnected(nil):
            break
        default:
            XCTFail("State is \(connectionRepository.connectionState). Expecting .notConnected(nil)")
        }
    }

    func testDefaultStateIsGuestIfProfileIsPresent() async throws {
        let guestExpectation = XCTestExpectation(description: "Guest profile present")

        // Precondition: user id and guest profile in db and no client user data
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "profileId", userId: "userId", nickname: "Guest", isGuest: true))

        let connectionRepository = makeConnectionRepository { state in
            switch state {
            case let .connected(user, nil) where user.profile.isGuest:
                guestExpectation.fulfill()
            default:
                break
            }
        }

        await fulfillment(of: [guestExpectation], timeout: 5)
        // The repository is only observed through its publisher, so it must be kept alive until the end.
        withExtendedLifetime(connectionRepository) { }
    }

    func testFromNonConnectedToGuest() async throws {
        let notConnectedExpectation = XCTestExpectation(description: "State is not connected")
        let guestExpectation = XCTestExpectation(description: "Guest profile present")

        // Precondition: no client user data, no user id, no profile in db
        try await setupWithNonConnectedWithoutErrorState()

        // The connect function will be called right after init since all preconditions are fullfilled. Mock backend response
        mockUserService.injectNextGetGuestJwtResponse(.with {
            $0.result = .success(.with {
                $0.jwt = "fakeJWT"
                $0.userID = "userId"
                $0.profile = .with {
                    $0.id = "profileId"
                    $0.nickname = "Guest"
                    $0.hasSeenOnboarding_p = false
                    $0.hasAcceptedCgu_p = false
                    $0.hasConfirmedNickname_p = false
                    $0.isGuest = true
                }
            })
        })

        let connectionRepository = makeConnectionRepository { state in
            switch state {
            case .notConnected(nil):
                notConnectedExpectation.fulfill()
            case let .connected(user, nil) where user.profile.isGuest:
                guestExpectation.fulfill()
            default:
                XCTFail("State is \(state).")
            }
        }

        await fulfillment(of: [notConnectedExpectation, guestExpectation], timeout: 5, enforceOrder: true)
        // The repository is only observed through its publisher, so it must be kept alive until the end.
        withExtendedLifetime(connectionRepository) { }
    }

    /// Before the device's first unlock after a reboot the stored session cannot be read. Connecting a guest then
    /// would replace the user's session: the guest connection waits for the session to be read, and only happens
    /// if there is none.
    func testNoGuestConnectionWhileTheSessionIsUnreadable() async throws {
        let notConnectedExpectation = XCTestExpectation(description: "State is not connected")
        let guestExpectation = XCTestExpectation(description: "Guest profile present")
        let securedStorage = injector.getInjected(identifiedBy: Injected.securedStorage) as! MockSecuredStorage
        securedStorage.readError = SecuredStorageError.unavailableUntilFirstUnlock
        _ = userDataStorage

        mockUserService.injectNextGetGuestJwtResponse(.with {
            $0.result = .success(.with {
                $0.jwt = "fakeJWT"
                $0.userID = "userId"
                $0.profile = .with {
                    $0.id = "profileId"
                    $0.nickname = "Guest"
                    $0.isGuest = true
                }
            })
        })

        let connectionRepository = makeConnectionRepository { state in
            switch state {
            case .notConnected(nil):
                notConnectedExpectation.fulfill()
            case let .connected(user, nil) where user.profile.isGuest:
                guestExpectation.fulfill()
            default:
                XCTFail("State is \(state).")
            }
        }
        await fulfillment(of: [notConnectedExpectation], timeout: 5)
        // leave time for a guest connection to happen if it were not waiting
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, 0, "no guest while the session is unreadable")

        // the device is unlocked, and there turns out to be no stored session
        securedStorage.readError = nil
        sessionReadTrigger.send()

        await fulfillment(of: [guestExpectation], timeout: 5)
        withExtendedLifetime(connectionRepository) { }
    }

    /// The case the guest connection waits for: a session stored before the reboot, unreadable until the device
    /// is unlocked, comes back as it was. No guest is connected over it, not even for a moment.
    func testAStoredSessionReadOnUnlockIsKeptWithoutAGuest() async throws {
        let notConnectedExpectation = XCTestExpectation(description: "State is not connected")
        let connectedExpectation = XCTestExpectation(description: "Stored user connected")
        let securedStorage = injector.getInjected(identifiedBy: Injected.securedStorage) as! MockSecuredStorage
        try storeSession(in: securedStorage, userId: "userId", clientUserId: "clientUserId")
        try await userProfileDatabase.upsert(profile: StorableCurrentUserProfile.create(
            id: "profileId", userId: "userId", nickname: "ClientUser", isGuest: false))
        securedStorage.readError = SecuredStorageError.unavailableUntilFirstUnlock
        _ = userDataStorage
        // were a guest connection attempted, it would succeed and show
        mockUserService.injectNextGetGuestJwtResponse(.with {
            $0.result = .success(.with {
                $0.jwt = "guestJWT"
                $0.userID = "guestUserId"
                $0.profile = .with {
                    $0.id = "guestProfileId"
                    $0.nickname = "Guest"
                    $0.isGuest = true
                }
            })
        })

        let connectionRepository = makeConnectionRepository { state in
            switch state {
            case .notConnected(nil):
                notConnectedExpectation.fulfill()
            case let .connected(user, nil) where user.profile.userId == "userId" && !user.profile.isGuest:
                connectedExpectation.fulfill()
            default:
                XCTFail("State is \(state).")
            }
        }
        await fulfillment(of: [notConnectedExpectation], timeout: 5)

        securedStorage.readError = nil
        sessionReadTrigger.send()

        await fulfillment(of: [connectedExpectation], timeout: 5)
        // leave time for a connection attempt started by the session read to show
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, 0, "no guest may be connected over the stored session")
        XCTAssertEqual(mockUserService.getJwtCallCount, 0, "the stored session needs no new token")
        XCTAssertEqual(userDataStorage.userData?.jwtToken, "jwt")
        XCTAssertEqual(try securedStorage.value(forKey: "user_jwtToken"), "jwt", "the stored session is untouched")
        withExtendedLifetime(connectionRepository) { }
    }

    /// A host connecting its user while the session is unreadable cannot tell who is connected yet: the SDK gives
    /// up rather than connect a guest that could later replace the stored session.
    func testConnectUserGivesUpWhileTheSessionIsUnreadable() async throws {
        let securedStorage = injector.getInjected(identifiedBy: Injected.securedStorage) as! MockSecuredStorage
        try storeSession(in: securedStorage, userId: "userId", clientUserId: "clientUserId")
        securedStorage.readError = SecuredStorageError.unavailableUntilFirstUnlock
        _ = userDataStorage
        let connectionRepository = SSOConnectionRepository(connectionMode: connectionMode, injector: injector)
        connectionRepository.unreadableSessionTimeout = 0.1
        var tokenRequested = false

        do {
            try await connectionRepository.connectUser(
                .init(userId: "clientUserId", profile: .init(nickname: "ClientUser", bio: nil, picture: nil)),
                tokenProvider: { tokenRequested = true; return "clientToken" })
            XCTFail("connectUser must fail while the session is unreadable")
        } catch {
            XCTAssertTrue(isUnreadableSessionError(error), "unexpected error \(error)")
        }

        XCTAssertFalse(tokenRequested)
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, 0, "no guest may be connected")
        XCTAssertEqual(mockUserService.getJwtCallCount, 0)
        XCTAssertNil(userDataStorage.userData)
        securedStorage.readError = nil
        XCTAssertEqual(try securedStorage.value(forKey: "user_jwtToken"), "jwt", "the stored session is untouched")
    }

    /// The unlock notification can be missed while the app is suspended: `connectUser` reads the session again
    /// on its own rather than fail while the Keychain has become readable.
    func testConnectUserReadsTheSessionAgainWithoutTheUnlockNotification() async throws {
        let securedStorage = injector.getInjected(identifiedBy: Injected.securedStorage) as! MockSecuredStorage
        try storeSession(in: securedStorage, userId: "userId", clientUserId: "clientUserId")
        try await userProfileDatabase.upsert(profile: StorableCurrentUserProfile.create(
            id: "profileId", userId: "userId", nickname: "ClientUser", isGuest: false))
        securedStorage.readError = SecuredStorageError.unavailableUntilFirstUnlock
        _ = userDataStorage
        let connectionRepository = SSOConnectionRepository(connectionMode: connectionMode, injector: injector)

        // the device is unlocked, but no notification tells the SDK
        securedStorage.readError = nil
        do {
            try await connectionRepository.connectUser(
                .init(userId: "clientUserId", profile: .init(nickname: "ClientUser", bio: nil, picture: nil)),
                tokenProvider: { "clientToken" })
        } catch {
            // Past the session, the connection can fail for reasons this test does not set up (community access…)
            XCTAssertFalse(isUnreadableSessionError(error), "connectUser gave up on a session that had become readable")
        }

        XCTAssertFalse(userDataStorage.sessionIsUnreadable)
        XCTAssertEqual(userDataStorage.userData?.id, "userId", "the stored session is the one read")
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, 0)
    }

    /// The device being unlocked while `connectUser` waits: it goes on with the session it can read now.
    func testConnectUserGoesOnWhenTheDeviceIsUnlockedDuringTheWait() async throws {
        let securedStorage = injector.getInjected(identifiedBy: Injected.securedStorage) as! MockSecuredStorage
        try storeSession(in: securedStorage, userId: "userId", clientUserId: "clientUserId")
        try await userProfileDatabase.upsert(profile: StorableCurrentUserProfile.create(
            id: "profileId", userId: "userId", nickname: "ClientUser", isGuest: false))
        securedStorage.readError = SecuredStorageError.unavailableUntilFirstUnlock
        // locked for the read at init and the first two reads of the wait, then unlocked
        securedStorage.readErrorLastsForReads = 3
        _ = userDataStorage
        let connectionRepository = SSOConnectionRepository(connectionMode: connectionMode, injector: injector)

        do {
            try await connectionRepository.connectUser(
                .init(userId: "clientUserId", profile: .init(nickname: "ClientUser", bio: nil, picture: nil)),
                tokenProvider: { "clientToken" })
        } catch {
            // Past the session, the connection can fail for reasons this test does not set up (community access…)
            XCTAssertFalse(isUnreadableSessionError(error), "connectUser gave up although the device was unlocked")
        }

        XCTAssertFalse(userDataStorage.sessionIsUnreadable)
        XCTAssertEqual(userDataStorage.userData?.id, "userId", "the stored session is the one read")
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, 0)
    }

    func testFromNonConnectedToGuestWithError() async throws {
        let notConnectedExpectation = XCTestExpectation(description: "State is not connected")
        let notConnectedWithErrorExpectation = XCTestExpectation(description: "State is not connected with error")

        // Precondition: no client user data, no user id, no profile in db
        try await setupWithNonConnectedWithoutErrorState()

        // The getGuestJwt service will be called right after init since all preconditions are fullfilled.
        // Mock backend response.
        mockUserService.injectNextGetGuestJwtResponse(.with {
            $0.result = .fail(.with {
                $0.errors = []
            })
        })

        let connectionRepository = makeConnectionRepository { state in
            switch state {
            case .notConnected(nil):
                notConnectedExpectation.fulfill()
            case .notConnected:
                notConnectedWithErrorExpectation.fulfill()
            default:
                XCTFail("State is \(state).")
            }
        }

        await fulfillment(of: [notConnectedExpectation, notConnectedWithErrorExpectation], timeout: 5,
                          enforceOrder: true)
        // The repository is only observed through its publisher, so it must be kept alive until the end.
        withExtendedLifetime(connectionRepository) { }
    }

    func testFromGuestToNonGuestAfterClientUserConnected() async throws {
        let notConnectedExpectation = XCTestExpectation(description: "State is not connected")
        let guestExpectation = XCTestExpectation(description: "Guest profile present")
        let authProfileExpectation = XCTestExpectation(description: "Authenticated profile present")

        // Precondition: user id and guest profile in db and no client user data
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "profileId", userId: "userId", nickname: "Guest", isGuest: true))

        let connectionRepository = makeConnectionRepository { state in
            switch state {
            case .notConnected(nil):
                notConnectedExpectation.fulfill()
            case let .connected(user, nil) where user.profile.isGuest:
                guestExpectation.fulfill()
            case let .connected(user, nil) where !user.profile.isGuest:
                authProfileExpectation.fulfill()
            default:
                XCTFail("State is \(state).")
            }
        }

        await fulfillment(of: [notConnectedExpectation, guestExpectation], timeout: 5,
                          enforceOrder: true)

        // The getFrictionlessJwt service will be called right after the connectUser
        // Mock backend response.
        mockUserService.injectNextGetJwtFromClientResponse(.with {
            $0.result = .success(.with {
                $0.jwt = "fakeJWT"
                $0.userID = "userId"
                $0.profile = .with {
                    $0.id = "profileId"
                    $0.nickname = "ClientNickName"
                    $0.hasSeenOnboarding_p = false
                    $0.hasAcceptedCgu_p = false
                    $0.hasConfirmedNickname_p = false
                    $0.isGuest = false
                }
            })
        })

        try await connectionRepository.connectUser(
            .init(userId: "clientUserId",
                  profile: .init(
                    nickname: "ClientNickName",
                    bio: "ClientBio",
                    picture: nil)),
            tokenProvider: { "CLIENT_TOKEN" }
        )

        await fulfillment(of: [authProfileExpectation], timeout: 5)
    }

    func testFromGuestToNonGuestAfterClientUserConnectedWithError() async throws {
        let notConnectedExpectation = XCTestExpectation(description: "State is not connected")
        let guestExpectation = XCTestExpectation(description: "Guest profile present")
        let guestWithErrorExpectation = XCTestExpectation(description: "Guest profile present with auth error")

        // Precondition: user id and guest profile in db and no client user data
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "profileId", userId: "userId", nickname: "Guest", isGuest: true))

        let connectionRepository = makeConnectionRepository { state in
            switch state {
            case .notConnected(nil):
                notConnectedExpectation.fulfill()
            case let .connected(user, nil) where user.profile.isGuest:
                guestExpectation.fulfill()
            case let .connected(user, _) where user.profile.isGuest:
                guestWithErrorExpectation.fulfill()
            default:
                XCTFail("State is \(state).")
            }
        }

        await fulfillment(of: [notConnectedExpectation, guestExpectation], timeout: 5,
                          enforceOrder: true)

        // The getFrictionlessJwt service will be called right after the connectUser
        // Mock backend response.
        mockUserService.injectNextGetJwtFromClientResponse(.with {
            $0.result = .fail(.with {
                $0.errors = []
            })
        })

        do {
            try await connectionRepository.connectUser(
                .init(userId: "clientUserId",
                      profile: .init(
                        nickname: "ClientNickName",
                        bio: "ClientBio",
                        picture: nil)),
                tokenProvider: { "CLIENT_TOKEN" }
            )
            XCTFail("connectUser should have thrown an error")
        } catch {
            // Expected: connection error is thrown when client user authentication fails
        }

        await fulfillment(of: [guestWithErrorExpectation], timeout: 5)
    }

    func testFromClientUserConnectedToAnotherClientConnected() async throws {
        let notConnectedExpectation = XCTestExpectation(description: "State is not connected")
        let connected1Expectation = XCTestExpectation(description: "Client user connected and profile present")
        let connected2Expectation = XCTestExpectation(description: "Another client user connected and profile present")

        // Precondition: user id and guest profile in db and no client user data
        try await setupWithClientUserProfile(StorableCurrentUserProfile.create(
            id: "profileId", userId: "firstUserId", nickname: "ClientUser1", isGuest: false),
        clientUserId: "clientUser1")

        let connectionRepository = makeConnectionRepository { state in
            switch state {
            case .notConnected(nil):
                notConnectedExpectation.fulfill()
            case let .connected(user, nil) where user.profile.userId == "firstUserId":
                connected1Expectation.fulfill()
            case let .connected(user, nil) where user.profile.userId == "newUserId":
                connected2Expectation.fulfill()
            default:
                XCTFail("State is \(state).")
            }
        }

        await fulfillment(of: [notConnectedExpectation, connected1Expectation], timeout: 5,
                          enforceOrder: true)

        // The getFrictionlessJwt service will be called right after the connectUser
        // Mock backend response.
        mockUserService.injectNextGetJwtFromClientResponse(.with {
            $0.result = .success(.with {
                $0.jwt = "fakeJWT"
                $0.userID = "newUserId"
                $0.profile = .with {
                    $0.id = "profileId"
                    $0.nickname = "ClientNickName"
                    $0.hasSeenOnboarding_p = false
                    $0.hasAcceptedCgu_p = false
                    $0.hasConfirmedNickname_p = false
                    $0.isGuest = false
                }
            })
        })

        try await connectionRepository.connectUser(
            .init(userId: "newClientUserId",
                  profile: .init(
                    nickname: "ClientNickName",
                    bio: "ClientBio",
                    picture: nil)),
            tokenProvider: { "CLIENT_TOKEN" }
        )

        await fulfillment(of: [connected2Expectation], timeout: 5)
    }

    func testConnectUserThrowsWhenGetJwtFails() async throws {
        // Precondition: user id and guest profile in db and no client user data
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "profileId", userId: "userId", nickname: "Guest", isGuest: true))

        let connectionRepository = SSOConnectionRepository(connectionMode: connectionMode, injector: injector)
        let guestExpectation = XCTestExpectation(description: "Guest profile present")
        connectionRepository.$connectionState.sink { state in
            if case let .connected(user, nil) = state, user.profile.isGuest {
                guestExpectation.fulfill()
            }
        }.store(in: &storage)
        await fulfillment(of: [guestExpectation], timeout: 5)

        // Mock getJwt to fail with userBanned
        mockUserService.injectNextGetJwtFromClientResponse(.with {
            $0.result = .fail(.with {
                $0.errors = [.with {
                    $0.errorCode = .userBanned
                    $0.message = "You have been banned"
                }]
            })
        })

        do {
            try await connectionRepository.connectUser(
                .init(userId: "clientUserId",
                      profile: .init(nickname: "Nick", bio: nil, picture: nil)),
                tokenProvider: { "CLIENT_TOKEN" }
            )
            XCTFail("connectUser should have thrown an error")
        } catch let error as ConnectionError {
            guard case let .detailedErrors(errors) = error else {
                XCTFail("Expected detailedErrors, got \(error)")
                return
            }
            XCTAssertEqual(errors.count, 1)
            XCTAssertEqual(errors.first?.reason, .userBanned)
            XCTAssertEqual(errors.first?.message, "You have been banned")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    /// A guest can be banned on its own, with no client user in the picture: the backend refuses the
    /// guest exchange itself. Until `GetGuestJwtResponse.ErrorCode` carried `USER_BANNED` the SDK could
    /// only see an unknown failure — the reason travelled in the human-readable `message`, which is not
    /// something to match on (matching the English sentence is what logged banned users out in every
    /// other locale). With the code in place the ban is now legible from the guest exchange too.
    func testBannedGuestSurfacesTheServerMessage() async throws {
        // Precondition: no client user data, no user id, no profile in db
        try await setupWithNonConnectedWithoutErrorState()

        mockUserService.injectNextGetGuestJwtResponse(.with {
            $0.result = .fail(.with {
                $0.errors = [.with {
                    $0.errorCode = .userBanned
                    $0.message = "Your account has been blocked."
                }]
            })
        })

        let bannedExpectation = XCTestExpectation(description: "Not connected, carrying the ban message")
        let connectionRepository = makeConnectionRepository { state in
            switch state {
            case .notConnected(nil):
                break
            case .notConnected:
                if state.userBannedMessage == "Your account has been blocked." {
                    bannedExpectation.fulfill()
                }
            default:
                XCTFail("State is \(state). A banned guest must not end up connected.")
            }
        }

        await fulfillment(of: [bannedExpectation], timeout: 5)
        XCTAssertEqual(connectionRepository.connectionState.userBannedMessage, "Your account has been blocked.")
    }

    /// A refused client-user exchange normally falls back to a guest session, so the community stays
    /// browsable through a passing failure. A ban must not take that exit: answering the server's refusal
    /// with a brand-new guest identity both hands the banned user a way around it and throws away the only
    /// explanation there was, leaving the UI with nothing to say but "try again in a few moments" — advice
    /// a banned user can only follow forever. The ban travels up to the caller instead.
    func testBanIsNotAnsweredWithAGuestSession() async throws {
        // Precondition: no client user data, no user id, no profile in db
        try await setupWithNonConnectedWithoutErrorState()

        // The guest connection attempted right after init fails, leaving the repository not connected:
        // this is the state in which the client-user exchange below would otherwise fall back to a guest.
        mockUserService.injectNextGetGuestJwtResponse(.with {
            $0.result = .fail(.with { $0.errors = [] })
        })

        let notConnectedWithErrorExpectation = XCTestExpectation(description: "State is not connected with error")
        let connectionRepository = makeConnectionRepository { state in
            switch state {
            case .notConnected(nil):
                break
            case .notConnected:
                notConnectedWithErrorExpectation.fulfill()
            default:
                XCTFail("State is \(state). A banned user must not end up on a guest session.")
            }
        }

        await fulfillment(of: [notConnectedWithErrorExpectation], timeout: 5)
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, 1)

        mockUserService.injectNextGetJwtFromClientResponse(.with {
            $0.result = .fail(.with {
                $0.errors = [.with {
                    $0.errorCode = .userBanned
                    $0.message = "You have been banned"
                }]
            })
        })

        do {
            try await connectionRepository.connectUser(
                .init(userId: "clientUserId", profile: .init(nickname: "Nick", bio: nil, picture: nil)),
                tokenProvider: { "CLIENT_TOKEN" }
            )
            XCTFail("connectUser should have thrown the ban instead of connecting a guest")
        } catch let error as ConnectionError {
            guard case let .detailedErrors(errors) = error else {
                XCTFail("Expected detailedErrors, got \(error)")
                return
            }
            XCTAssertEqual(errors.first?.reason, .userBanned)
            XCTAssertEqual(errors.first?.message, "You have been banned")
        }

        // No second guest exchange was attempted, and the state still carries the server's own wording.
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, 1)
        XCTAssertEqual(connectionRepository.connectionState.userBannedMessage, "You have been banned")
    }

    func testConnectUserThrowsProfileErrorWhenNicknameAlreadyTaken() async throws {
        // Precondition: user id and guest profile in db and no client user data
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "profileId", userId: "userId", nickname: "Guest", isGuest: true))

        let connectionRepository = SSOConnectionRepository(connectionMode: connectionMode, injector: injector)
        let guestExpectation = XCTestExpectation(description: "Guest profile present")
        connectionRepository.$connectionState.sink { state in
            if case let .connected(user, nil) = state, user.profile.isGuest {
                guestExpectation.fulfill()
            }
        }.store(in: &storage)
        await fulfillment(of: [guestExpectation], timeout: 5)

        // Mock getJwt to succeed (non-frictionless but nickname not confirmed, so merger will update it)
        mockUserService.injectNextGetJwtFromClientResponse(.with {
            $0.result = .success(.with {
                $0.jwt = "fakeJWT"
                $0.userID = "userId"
                $0.profile = .with {
                    $0.id = "profileId"
                    $0.nickname = "OldNickname"
                    $0.hasConfirmedNickname_p = false
                    $0.hasConfirmedBio_p = true
                    $0.hasConfirmedPicture_p = true
                    $0.isGuest = false
                }
            })
        })

        // Mock updateProfile to fail with nickname already taken
        mockUserService.injectNextUpdateProfileResponse(.with {
            $0.result = .fail(.with {
                $0.errors = [.with {
                    $0.field = .nickname
                    $0.details = .alreadyTaken(.init())
                    $0.message = "Nickname is already taken"
                }]
            })
        })

        do {
            try await connectionRepository.connectUser(
                .init(userId: "clientUserId",
                      profile: .init(nickname: "TakenNickname", bio: nil, picture: nil)),
                tokenProvider: { "CLIENT_TOKEN" }
            )
            XCTFail("connectUser should have thrown an error")
        } catch let error as ConnectionError {
            guard case let .profileUpdateError(updateError) = error else {
                XCTFail("Expected profileUpdateError, got \(error)")
                return
            }
            guard case let .validation(validationErrors) = updateError else {
                XCTFail("Expected validation error, got \(updateError)")
                return
            }
            let nicknameErrors = validationErrors.errors[.linkedToField(.nickname)]
            XCTAssertNotNil(nicknameErrors)
            XCTAssertEqual(nicknameErrors?.count, 1)
            guard case .alreadyTaken = nicknameErrors?.first?.detail else {
                XCTFail("Expected alreadyTaken, got \(String(describing: nicknameErrors?.first?.detail))")
                return
            }
            XCTAssertEqual(nicknameErrors?.first?.localizedMessage, "Nickname is already taken")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testConnectUserThrowsProfileErrorWhenAlreadyConnectedAndSyncFails() async throws {
        // Precondition: connected non-guest user with clientUserId, nickname not confirmed so merger will sync
        try await setupWithClientUserProfile(StorableCurrentUserProfile.create(
            id: "profileId", userId: "userId", nickname: "OldNickname",
            hasConfirmedNickname: false, isGuest: false),
        clientUserId: "clientUser1")

        // Ensure community access is granted before creating the repository so the CombineLatest4 pipeline fires
        try await userConfigDatabase.upsert(canAccessCommunity: true, message: nil)
        let configRepository: ConfigRepository = injector.getInjected(identifiedBy: Injected.configRepository)
        try? await TaskUtils.wait(for: configRepository.userConfig?.canAccessCommunity == true, timeout: 2)

        let connectionRepository = SSOConnectionRepository(connectionMode: connectionMode, injector: injector)
        let connectedExpectation = XCTestExpectation(description: "Client user connected")
        connectionRepository.$connectionState.sink { state in
            if case let .connected(user, nil) = state, !user.profile.isGuest {
                connectedExpectation.fulfill()
            }
        }.store(in: &storage)
        await fulfillment(of: [connectedExpectation], timeout: 5)

        // Mock updateProfile to fail with nickname already taken (triggered by Combine pipeline)
        mockUserService.injectNextUpdateProfileResponse(.with {
            $0.result = .fail(.with {
                $0.errors = [.with {
                    $0.field = .nickname
                    $0.details = .alreadyTaken(.init())
                    $0.message = "Nickname is already taken"
                }]
            })
        })

        do {
            // Call connectUser with same userId but different nickname — tokenNeeded will be false
            try await connectionRepository.connectUser(
                .init(userId: "clientUser1",
                      profile: .init(nickname: "NewNickname", bio: nil, picture: nil)),
                tokenProvider: { "CLIENT_TOKEN" }
            )
            XCTFail("connectUser should have thrown an error")
        } catch let error as ConnectionError {
            guard case let .profileUpdateError(updateError) = error else {
                XCTFail("Expected profileUpdateError, got \(error)")
                return
            }
            guard case let .validation(validationErrors) = updateError else {
                XCTFail("Expected validation error, got \(updateError)")
                return
            }
            let nicknameErrors = validationErrors.errors[.linkedToField(.nickname)]
            XCTAssertNotNil(nicknameErrors)
            XCTAssertEqual(nicknameErrors?.count, 1)
            guard case .alreadyTaken = nicknameErrors?.first?.detail else {
                XCTFail("Expected alreadyTaken, got \(String(describing: nicknameErrors?.first?.detail))")
                return
            }
            XCTAssertEqual(nicknameErrors?.first?.localizedMessage, "Nickname is already taken")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    /// A user the A/B test keeps away from the community gets their Octopus account from the exchange, then the
    /// server refuses to update its profile. They must stay connected with that account: the SDK used to fall
    /// back to a guest, which created a guest account each time the app was launched again.
    func testClientUserWithoutCommunityAccessStaysConnectedWithTheirAccount() async throws {
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "guestProfileId", userId: "guestUserId", nickname: "Guest", isGuest: true))
        try await setCommunityAccess(false)

        let guestExpectation = XCTestExpectation(description: "Connected as guest")
        let clientUserConnectedExpectation = XCTestExpectation(description: "Connected with their account")
        let connectionRepository = makeConnectionRepository { state in
            guard case let .connected(user, _) = state else { return }
            if user.profile.isGuest {
                guestExpectation.fulfill()
            } else if user.profile.id == "clientProfileId" {
                clientUserConnectedExpectation.fulfill()
            }
        }
        await fulfillment(of: [guestExpectation], timeout: 5)

        try await connectClientUserRefusedCommunityAccess(connectionRepository)

        await fulfillment(of: [clientUserConnectedExpectation], timeout: 5)
        XCTAssertEqual(userDataStorage.userData?.id, "clientUserId")
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, 0)
    }

    /// The state the guest fallback used to leave behind: the session of the client user is stored, but not its
    /// profile. On the next launch, the refused profile update must not be answered with a guest either.
    func testStoredSessionWithoutCommunityAccessIsNotReplacedByAGuest() async throws {
        userDataStorage.store(userData: .init(id: "clientUserId", clientId: "clientUser", jwtToken: "oldJwt"))
        userDataStorage.store(clientUserData: .init(id: "clientUser"))
        try await setCommunityAccess(false)

        let clientUserConnectedExpectation = XCTestExpectation(description: "Connected with their account")
        let connectionRepository = makeConnectionRepository { state in
            if case let .connected(user, _) = state, user.profile.id == "clientProfileId" {
                clientUserConnectedExpectation.fulfill()
            }
        }

        try await connectClientUserRefusedCommunityAccess(connectionRepository)

        await fulfillment(of: [clientUserConnectedExpectation], timeout: 5)
        XCTAssertEqual(userDataStorage.userData?.id, "clientUserId")
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, 0)
    }

    /// Once the community opens to the user, the profile update that was refused is sent again, with the session
    /// they already have: their token is not exchanged a second time.
    func testClientUserProfileIsUpdatedOnceCommunityAccessIsGranted() async throws {
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "guestProfileId", userId: "guestUserId", nickname: "Guest", isGuest: true))
        try await setCommunityAccess(false)

        let guestExpectation = XCTestExpectation(description: "Connected as guest")
        let updatedProfileExpectation = XCTestExpectation(description: "Connected with the updated profile")
        let connectionRepository = makeConnectionRepository { state in
            guard case let .connected(user, _) = state else { return }
            if user.profile.isGuest {
                guestExpectation.fulfill()
            } else if user.profile.nickname == "ClientNickname" {
                updatedProfileExpectation.fulfill()
            }
        }
        await fulfillment(of: [guestExpectation], timeout: 5)

        try await connectClientUserRefusedCommunityAccess(connectionRepository)

        mockUserService.injectNextUpdateProfileResponse(clientUserUpdatedProfileResponse())
        try await setCommunityAccess(true)

        await fulfillment(of: [updatedProfileExpectation], timeout: 5)
        XCTAssertEqual(mockUserService.getJwtCallCount, 1)
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, 0)
    }

    /// A host can call `connectUser` on every foreground while the community is closed. Each call is refused, and
    /// the refusals do not use up the tries the merger allows the same update: every call throws
    /// `communityAccessDenied`, and the profile is sent once the community opens.
    func testRepeatedConnectUserWhileTheCommunityIsClosedStillSendsTheProfileOnceItOpens() async throws {
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "guestProfileId", userId: "guestUserId", nickname: "Guest", isGuest: true))
        try await setCommunityAccess(false)

        let guestExpectation = XCTestExpectation(description: "Connected as guest")
        let updatedProfileExpectation = XCTestExpectation(description: "Connected with the updated profile")
        let connectionRepository = makeConnectionRepository { state in
            guard case let .connected(user, nil) = state else { return }
            if user.profile.isGuest {
                guestExpectation.fulfill()
            } else if user.profile.nickname == "ClientNickname" {
                updatedProfileExpectation.fulfill()
            }
        }
        await fulfillment(of: [guestExpectation], timeout: 5)

        for _ in 0..<4 {
            try await connectClientUserRefusedCommunityAccess(connectionRepository)
        }

        mockUserService.injectNextUpdateProfileResponse(clientUserUpdatedProfileResponse())
        try await setCommunityAccess(true)

        await fulfillment(of: [updatedProfileExpectation], timeout: 5)
        XCTAssertEqual(mockUserService.updateProfileCallCount, 5)
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, 0)
    }

    /// When the update of the profile fails after the exchange for another reason than a refusal of access, the user
    /// keeps their account and `connectUser` reports it, as on Android. Nothing waits for the community to open.
    func testProfileUpdateFailureAfterTheExchangeKeepsTheAccount() async throws {
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "guestProfileId", userId: "guestUserId", nickname: "Guest", isGuest: true))
        try await setCommunityAccess(false)

        let guestExpectation = XCTestExpectation(description: "Connected as guest")
        let clientUserConnectedExpectation = XCTestExpectation(description: "Connected with their account")
        let connectionRepository = makeConnectionRepository { state in
            guard case let .connected(user, error) = state else { return }
            if user.profile.isGuest {
                if error == nil { guestExpectation.fulfill() }
            } else if user.profile.id == "clientProfileId", error != nil {
                clientUserConnectedExpectation.fulfill()
            }
        }
        await fulfillment(of: [guestExpectation], timeout: 5)

        mockUserService.injectNextGetJwtFromClientResponse(clientUserJwtResponse())
        mockUserService.injectNextUpdateProfileError(.timeout)
        injectNewGuestResponse()
        do {
            try await connectClientUser(connectionRepository)
            XCTFail("connectUser should have thrown an error")
        } catch let error as ConnectionError {
            guard case .profileUpdateError = error else {
                XCTFail("Expected profileUpdateError, got \(error)")
                return
            }
        }

        await fulfillment(of: [clientUserConnectedExpectation], timeout: 5)
        XCTAssertEqual(userDataStorage.userData?.id, "clientUserId")

        // With their account stored, the profile repository sends the update once the community opens: nothing
        // connects them again.
        let updatedProfileExpectation = XCTestExpectation(description: "Profile updated")
        connectionRepository.$connectionState
            .sink {
                if case let .connected(user, _) = $0, user.profile.nickname == "ClientNickname" {
                    updatedProfileExpectation.fulfill()
                }
            }.store(in: &storage)
        mockUserService.injectNextUpdateProfileResponse(clientUserUpdatedProfileResponse())
        try await setCommunityAccess(true)
        await fulfillment(of: [updatedProfileExpectation], timeout: 5)
        XCTAssertEqual(mockUserService.getJwtCallCount, 1)
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, 0)
    }

    /// A connection can store the very session and profile the failed one left, as when the host passes the nickname
    /// the user already has: the state sees nothing change, and the error the failed connection left is cleared.
    func testConnectionStoringTheSameSessionAsTheFailedOneClearsItsError() async throws {
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "guestProfileId", userId: "guestUserId", nickname: "Guest", isGuest: true))
        try await setCommunityAccess(true)

        let guestExpectation = XCTestExpectation(description: "Connected as guest")
        let failedExpectation = XCTestExpectation(description: "Connected with their account and an error")
        let clearedExpectation = XCTestExpectation(description: "Connected with their account without an error")
        let connectionRepository = makeConnectionRepository { state in
            guard case let .connected(user, error) = state else { return }
            if user.profile.isGuest {
                if error == nil { guestExpectation.fulfill() }
            } else if user.profile.id == "clientProfileId" {
                if error != nil { failedExpectation.fulfill() } else { clearedExpectation.fulfill() }
            }
        }
        await fulfillment(of: [guestExpectation], timeout: 5)

        mockUserService.injectNextGetJwtFromClientResponse(clientUserJwtResponse())
        mockUserService.injectNextUpdateProfileError(.timeout)
        mockUserService.injectNextUpdateProfileError(.timeout)
        try? await connectClientUser(connectionRepository)
        await fulfillment(of: [failedExpectation], timeout: 5)

        // the same exchange, and the nickname the user already has: nothing to update
        mockUserService.injectNextGetJwtFromClientResponse(clientUserJwtResponse())
        try await connectionRepository.connectUser(
            .init(userId: "clientUser", profile: .init(nickname: "OctopusNickname", bio: nil, picture: nil)),
            tokenProvider: { "CLIENT_TOKEN" })

        await fulfillment(of: [clearedExpectation], timeout: 5)
    }

    /// The access the SDK read on its previous launch can open the community before the server closes it. The profile
    /// of the client user is sent once it really opens, and the refusal of access no longer stands then.
    func testClientUserProfileIsUpdatedWithoutErrorOnceCommunityAccessIsGrantedAgain() async throws {
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "guestProfileId", userId: "guestUserId", nickname: "Guest", isGuest: true))
        try await setCommunityAccess(true)

        let guestExpectation = XCTestExpectation(description: "Connected as guest")
        let updatedProfileExpectation = XCTestExpectation(description: "Connected with the updated profile")
        let connectionRepository = makeConnectionRepository { state in
            guard case let .connected(user, nil) = state else { return }
            if user.profile.isGuest {
                guestExpectation.fulfill()
            } else if user.profile.nickname == "ClientNickname" {
                updatedProfileExpectation.fulfill()
            }
        }
        await fulfillment(of: [guestExpectation], timeout: 5)
        try await setCommunityAccess(false)

        try await connectClientUserRefusedCommunityAccess(connectionRepository)
        // leave the profile repository the time to send an update while the community is closed
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(mockUserService.updateProfileCallCount, 1, "nothing sent while the community is closed")

        mockUserService.injectNextUpdateProfileResponse(clientUserUpdatedProfileResponse())
        try await setCommunityAccess(true)

        await fulfillment(of: [updatedProfileExpectation], timeout: 5)
        XCTAssertEqual(mockUserService.updateProfileCallCount, 2)
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, 0)
    }

    /// A profile from before frictionless profiles is migrated with an update of its own, which the server refuses
    /// too. The user then has their account with a profile still to migrate: they are connected again once the
    /// community opens to them, which migrates it.
    func testClientUserWhoseMigrationIsRefusedIsConnectedOnceCommunityAccessIsGranted() async throws {
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "guestProfileId", userId: "guestUserId", nickname: "Guest", isGuest: true))
        try await setCommunityAccess(false)

        let guestExpectation = XCTestExpectation(description: "Connected as guest")
        let updatedProfileExpectation = XCTestExpectation(description: "Connected with the updated profile")
        let connectionRepository = makeConnectionRepository { state in
            guard case let .connected(user, nil) = state else { return }
            if user.profile.isGuest {
                guestExpectation.fulfill()
            } else if user.profile.nickname == "ClientNickname" {
                updatedProfileExpectation.fulfill()
            }
        }
        await fulfillment(of: [guestExpectation], timeout: 5)

        try await connectClientUserRefusedCommunityAccess(connectionRepository,
                                                          exchange: legacyClientUserJwtResponse())

        mockUserService.injectNextGetJwtFromClientResponse(clientUserJwtResponse())
        mockUserService.injectNextUpdateProfileResponse(clientUserUpdatedProfileResponse())
        try await setCommunityAccess(true)

        await fulfillment(of: [updatedProfileExpectation], timeout: 5)
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, 0)
    }

    /// The access the SDK read on its previous launch can still say the community is open when the server refuses
    /// the migration of the profile because it is closed. The user is connected again once it really opens, which
    /// migrates it.
    func testClientUserWhoseMigrationIsRefusedWhileTheCommunityLooksOpenIsConnectedOnceItOpens() async throws {
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "guestProfileId", userId: "guestUserId", nickname: "Guest", isGuest: true))
        try await setCommunityAccess(true)

        let guestExpectation = XCTestExpectation(description: "Connected as guest")
        let updatedProfileExpectation = XCTestExpectation(description: "Connected with the updated profile")
        let connectionRepository = makeConnectionRepository { state in
            guard case let .connected(user, nil) = state else { return }
            if user.profile.isGuest {
                guestExpectation.fulfill()
            } else if user.profile.nickname == "ClientNickname" {
                updatedProfileExpectation.fulfill()
            }
        }
        await fulfillment(of: [guestExpectation], timeout: 5)

        try await connectClientUserRefusedCommunityAccess(connectionRepository,
                                                          exchange: legacyClientUserJwtResponse())
        try await setCommunityAccess(false)

        mockUserService.injectNextGetJwtFromClientResponse(clientUserJwtResponse())
        mockUserService.injectNextUpdateProfileResponse(clientUserUpdatedProfileResponse())
        try await setCommunityAccess(true)

        await fulfillment(of: [updatedProfileExpectation], timeout: 5)
        XCTAssertEqual(mockUserService.getJwtCallCount, 2)
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, 0)
    }

    /// When the migration of their profile fails for a passing reason, the user is connected with the account the
    /// exchange gave them, as on Android, not with the guest they had before. Their profile reads as the migration
    /// would leave it, and their next connection migrates it.
    func testClientUserWhoseMigrationFailsIsMigratedOnTheirNextConnection() async throws {
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "guestProfileId", userId: "guestUserId", nickname: "Guest", isGuest: true))
        try await setCommunityAccess(true)

        let guestExpectation = XCTestExpectation(description: "Connected as guest")
        let unmigratedProfileExpectation = XCTestExpectation(description: "Connected with their unmigrated profile")
        let clientUserConnectedExpectation = XCTestExpectation(description: "Connected with their account")
        let connectionRepository = makeConnectionRepository { state in
            guard case let .connected(user, error) = state else { return }
            if user.profile.isGuest {
                if error == nil { guestExpectation.fulfill() }
            } else if user.profile.id == "clientProfileId" {
                if error == nil {
                    clientUserConnectedExpectation.fulfill()
                } else if user.profile.hasConfirmedNickname, user.profile.hasAcceptedCgu {
                    // a profile created before frictionless profiles is migrated as fully confirmed
                    unmigratedProfileExpectation.fulfill()
                }
            }
        }
        await fulfillment(of: [guestExpectation], timeout: 5)

        mockUserService.injectNextGetJwtFromClientResponse(legacyClientUserJwtResponse())
        mockUserService.injectNextUpdateProfileError(.timeout)
        do {
            try await connectClientUser(connectionRepository)
            XCTFail("connectUser should have thrown an error")
        } catch let error as ConnectionError {
            guard case .profileUpdateError = error else {
                XCTFail("Expected profileUpdateError, got \(error)")
                return
            }
        }
        await fulfillment(of: [unmigratedProfileExpectation], timeout: 5)
        // stored with the confirmations the migration sets, but the nickname one, which tells it is still to migrate
        let storedProfile = Locked<StorableCurrentUserProfile?>(nil)
        userProfileDatabase.profilePublisher(userId: "clientUserId")
            .sink { storedProfile.value = $0 }
            .store(in: &storage)
        try? await TaskUtils.wait(for: storedProfile.value != nil, timeout: 2)
        XCTAssertNil(storedProfile.value?.hasConfirmedNickname)
        XCTAssertEqual(storedProfile.value?.hasAcceptedCgu, true)
        XCTAssertEqual(userDataStorage.userData?.id, "clientUserId")
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, 0)

        mockUserService.injectNextGetJwtFromClientResponse(legacyClientUserJwtResponse())
        mockUserService.injectNextUpdateProfileResponse(.with {
            $0.result = .success(.with {
                $0.profile = .with {
                    $0.id = "clientProfileId"
                    $0.nickname = "OctopusNickname"
                    $0.hasSeenOnboarding_p = true
                    $0.hasAcceptedCgu_p = true
                    $0.hasConfirmedNickname_p = true
                    $0.hasConfirmedBio_p = true
                    $0.hasConfirmedPicture_p = true
                    $0.isGuest = false
                }
            })
        })
        try await connectClientUser(connectionRepository)

        await fulfillment(of: [clientUserConnectedExpectation], timeout: 5)
        XCTAssertEqual(mockUserService.updateProfileCallCount, 2, "the migration is sent again")
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, 0)
    }

    /// A user who never went through the creation of their profile is migrated without anything confirmed. When
    /// that migration fails, their profile must not read as confirmed: they choose their nickname and accept the
    /// terms before they post. Nor is the nickname of the client user sent to it before it is migrated: the next
    /// migration would take it for a profile created before frictionless ones, and confirm everything.
    func testUnmigratedProfileWithoutNicknameIsLeftToConfirm() async throws {
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "guestProfileId", userId: "guestUserId", nickname: "Guest", isGuest: true))
        try await setCommunityAccess(true)

        let guestExpectation = XCTestExpectation(description: "Connected as guest")
        let clientUserConnectedExpectation = XCTestExpectation(description: "Connected with their account")
        let connectionRepository = makeConnectionRepository { state in
            guard case let .connected(user, _) = state else { return }
            if user.profile.isGuest {
                guestExpectation.fulfill()
            } else if user.profile.id == "clientProfileId" {
                XCTAssertFalse(user.profile.hasSeenOnboarding)
                XCTAssertFalse(user.profile.hasAcceptedCgu)
                XCTAssertFalse(user.profile.hasConfirmedNickname)
                clientUserConnectedExpectation.fulfill()
            }
        }
        await fulfillment(of: [guestExpectation], timeout: 5)

        var exchange = legacyClientUserJwtResponse()
        exchange.success.profile.nickname = ""
        mockUserService.injectNextGetJwtFromClientResponse(exchange)
        mockUserService.injectNextUpdateProfileError(.timeout)
        // so that an update sent with the nickname of the client user shows in the count
        mockUserService.injectNextUpdateProfileError(.timeout)
        try? await connectClientUser(connectionRepository)

        await fulfillment(of: [clientUserConnectedExpectation], timeout: 5)
        // leave the profile repository the time to send an update
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(mockUserService.updateProfileCallCount, 1, "only the migration is sent")
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, 0)
    }

    /// The account a failed migration leaves the user with is theirs, not a guest's: disconnecting them drops it,
    /// and the community is browsed as a guest again. Disconnected as soon as `connectUser` throws, before the
    /// state shows their account, as a host answering the error would.
    func testDisconnectUserAfterAFailedMigrationDropsTheClientSession() async throws {
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "guestProfileId", userId: "guestUserId", nickname: "Guest", isGuest: true))
        try await setCommunityAccess(true)

        let guestExpectation = XCTestExpectation(description: "Connected as guest")
        let newGuestExpectation = XCTestExpectation(description: "Connected as a guest again")
        let connectionRepository = makeConnectionRepository { state in
            guard case let .connected(user, _) = state else { return }
            switch user.profile.id {
            case "guestProfileId": guestExpectation.fulfill()
            case "newGuestProfileId": newGuestExpectation.fulfill()
            default: break
            }
        }
        await fulfillment(of: [guestExpectation], timeout: 5)

        mockUserService.injectNextGetJwtFromClientResponse(legacyClientUserJwtResponse())
        mockUserService.injectNextUpdateProfileError(.timeout)
        try? await connectClientUser(connectionRepository)

        injectNewGuestResponse()
        try await connectionRepository.disconnectUser()

        await fulfillment(of: [newGuestExpectation], timeout: 5)
        XCTAssertNil(userDataStorage.clientUserData)
        XCTAssertEqual(userDataStorage.userData?.id, "newGuestUserId")
        // nor does their profile stay on the device
        let clientProfileIsDeleted = Locked<Bool>(false)
        userProfileDatabase.profilePublisher(userId: "clientUserId")
            .sink { clientProfileIsDeleted.value = $0 == nil }
            .store(in: &storage)
        try? await TaskUtils.wait(for: clientProfileIsDeleted.value, timeout: 2)
        XCTAssertTrue(clientProfileIsDeleted.value)
    }

    /// The stored session tells a guest from a client user, not the state: the exchange replaces the guest's session
    /// before the state shows the client user's account. Without their profile, it never does.
    func testDisconnectUserDropsAClientSessionTheStateDoesNotShow() async throws {
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "guestProfileId", userId: "guestUserId", nickname: "Guest", isGuest: true))

        let guestExpectation = XCTestExpectation(description: "Connected as guest")
        let newGuestExpectation = XCTestExpectation(description: "Connected as a guest again")
        let connectionRepository = makeConnectionRepository { state in
            guard case let .connected(user, _) = state else { return }
            switch user.profile.id {
            case "guestProfileId": guestExpectation.fulfill()
            case "newGuestProfileId": newGuestExpectation.fulfill()
            default: break
            }
        }
        await fulfillment(of: [guestExpectation], timeout: 5)

        storeClientSessionWithoutProfile()
        injectNewGuestResponse()
        try await connectionRepository.disconnectUser()

        await fulfillment(of: [newGuestExpectation], timeout: 5)
        XCTAssertNil(userDataStorage.clientUserData)
        XCTAssertEqual(userDataStorage.userData?.id, "newGuestUserId")
    }

    /// Same as `testDisconnectUserDropsAClientSessionTheStateDoesNotShow`, for a call the server refuses: the client
    /// user is logged out, not kept as if they were the guest.
    func testAuthenticatedCallFailureDropsAClientSessionTheStateDoesNotShow() async throws {
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "guestProfileId", userId: "guestUserId", nickname: "Guest", isGuest: true))

        let guestExpectation = XCTestExpectation(description: "Connected as guest")
        let newGuestExpectation = XCTestExpectation(description: "Connected as a guest again")
        let connectionRepository = makeConnectionRepository { state in
            guard case let .connected(user, _) = state else { return }
            switch user.profile.id {
            case "guestProfileId": guestExpectation.fulfill()
            case "newGuestProfileId": newGuestExpectation.fulfill()
            default: break
            }
        }
        await fulfillment(of: [guestExpectation], timeout: 5)

        storeClientSessionWithoutProfile()
        injectNewGuestResponse()
        try? await connectionRepository.onAuthenticatedCallFailed()

        await fulfillment(of: [newGuestExpectation], timeout: 5)
        XCTAssertEqual(userDataStorage.userData?.id, "newGuestUserId")
    }

    /// A renewed token is stored before the state shows it: the guest is still a guest, and keeps their identity.
    func testGuestWhoseTokenIsRenewedIsKeptOnAuthenticatedCallFailure() async throws {
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "guestProfileId", userId: "guestUserId", nickname: "Guest", isGuest: true))

        let guestExpectation = XCTestExpectation(description: "Connected as guest")
        let connectionRepository = makeConnectionRepository { state in
            if case let .connected(user, _) = state, user.profile.isGuest {
                guestExpectation.fulfill()
            }
        }
        await fulfillment(of: [guestExpectation], timeout: 5)

        userDataStorage.store(userData: .init(id: "guestUserId", jwtToken: "renewedJwt"))
        try await connectionRepository.onAuthenticatedCallFailed()

        XCTAssertEqual(userDataStorage.userData?.id, "guestUserId")
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, 0)
    }

    /// A profile that is still to migrate is not filled with the info of the client user: a nickname the host
    /// manages would be sent as confirmed, and the server would never be asked to migrate the profile again.
    func testProfileStillToMigrateIsNotFilledWithAnAppManagedNickname() async throws {
        appManagedFields = [.nickname]
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "guestProfileId", userId: "guestUserId", nickname: "Guest", isGuest: true))
        try await setCommunityAccess(true)

        let guestExpectation = XCTestExpectation(description: "Connected as guest")
        let clientUserConnectedExpectation = XCTestExpectation(description: "Connected with their account")
        let connectionRepository = makeConnectionRepository { state in
            guard case let .connected(user, _) = state else { return }
            if user.profile.isGuest {
                guestExpectation.fulfill()
            } else if user.profile.id == "clientProfileId" {
                clientUserConnectedExpectation.fulfill()
            }
        }
        await fulfillment(of: [guestExpectation], timeout: 5)

        mockUserService.injectNextGetJwtFromClientResponse(legacyClientUserJwtResponse())
        mockUserService.injectNextUpdateProfileError(.timeout)
        // so that an update sent with the nickname of the client user shows in the count
        mockUserService.injectNextUpdateProfileError(.timeout)
        try? await connectClientUser(connectionRepository)

        await fulfillment(of: [clientUserConnectedExpectation], timeout: 5)
        // leave the profile repository the time to send an update
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(mockUserService.updateProfileCallCount, 1, "only the migration is sent")
    }

    /// A profile still to migrate, as a failed migration leaves it, is migrated by the next `connectUser`, also on a
    /// later launch, where the state carries no error any more.
    func testProfileStillToMigrateIsMigratedByTheNextConnectUser() async throws {
        try await setupWithClientUserProfile(StorableCurrentUserProfile.create(
            id: "clientProfileId", userId: "clientUserId", nickname: "OctopusNickname", hasConfirmedNickname: nil),
                                             clientUserId: "clientUser")
        try await setCommunityAccess(true)

        let clientUserConnectedExpectation = XCTestExpectation(description: "Connected with their account")
        let connectionRepository = makeConnectionRepository { state in
            if case let .connected(user, nil) = state, user.profile.id == "clientProfileId" {
                clientUserConnectedExpectation.fulfill()
            }
        }
        await fulfillment(of: [clientUserConnectedExpectation], timeout: 5)

        mockUserService.injectNextGetJwtFromClientResponse(legacyClientUserJwtResponse())
        mockUserService.injectNextUpdateProfileResponse(.with {
            $0.result = .success(.with {
                $0.profile = .with {
                    $0.id = "clientProfileId"
                    $0.nickname = "OctopusNickname"
                    $0.hasSeenOnboarding_p = true
                    $0.hasAcceptedCgu_p = true
                    $0.hasConfirmedNickname_p = true
                    $0.hasConfirmedBio_p = true
                    $0.hasConfirmedPicture_p = true
                    $0.isGuest = false
                }
            })
        })
        try await connectClientUser(connectionRepository)

        XCTAssertEqual(mockUserService.getJwtCallCount, 1)
        XCTAssertEqual(mockUserService.updateProfileCallCount, 1, "the migration is sent")
    }

    /// With the community open, a refused profile update leaves the user with their account, and the profile
    /// repository sends the update once more, not in a loop.
    func testRefusedProfileUpdateWithTheCommunityOpenKeepsTheAccount() async throws {
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "guestProfileId", userId: "guestUserId", nickname: "Guest", isGuest: true))
        try await setCommunityAccess(true)

        let guestExpectation = XCTestExpectation(description: "Connected as guest")
        let clientUserConnectedExpectation = XCTestExpectation(description: "Connected with their account")
        let connectionRepository = makeConnectionRepository { state in
            guard case let .connected(user, _) = state else { return }
            if user.profile.isGuest {
                guestExpectation.fulfill()
            } else if user.profile.id == "clientProfileId" {
                clientUserConnectedExpectation.fulfill()
            }
        }
        await fulfillment(of: [guestExpectation], timeout: 5)

        mockUserService.injectNextGetJwtFromClientResponse(clientUserJwtResponse())
        mockUserService.injectNextUpdateProfileError(.permissionDenied(reason: nil))
        mockUserService.injectNextUpdateProfileError(.permissionDenied(reason: nil))
        do {
            try await connectClientUser(connectionRepository)
            XCTFail("connectUser should have thrown an error")
        } catch let error as ConnectionError {
            // the user config can still be the guest's at that point: any refusal is taken for an access one
            guard case .communityAccessDenied = error else {
                XCTFail("Expected communityAccessDenied, got \(error)")
                return
            }
        }

        await fulfillment(of: [clientUserConnectedExpectation], timeout: 5)
        try? await TaskUtils.wait(for: mockUserService.updateProfileCallCount == 2, timeout: 2)
        // leave a third update the time to be sent
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(mockUserService.updateProfileCallCount, 2)
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, 0)
    }

    /// The profile of the client user is stored once it is filled with their info. Stored earlier, it had the
    /// profile repository send the same update a second time, while the one of the connection was in flight.
    func testClientUserProfileIsUpdatedOnceWhenTheCommunityIsOpen() async throws {
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "guestProfileId", userId: "guestUserId", nickname: "Guest", isGuest: true))
        try await setCommunityAccess(true)

        let guestExpectation = XCTestExpectation(description: "Connected as guest")
        let updatedProfileExpectation = XCTestExpectation(description: "Connected with the updated profile")
        let connectionRepository = makeConnectionRepository { state in
            guard case let .connected(user, nil) = state else { return }
            if user.profile.isGuest {
                guestExpectation.fulfill()
            } else if user.profile.nickname == "ClientNickname" {
                updatedProfileExpectation.fulfill()
            }
        }
        await fulfillment(of: [guestExpectation], timeout: 5)

        // the profile repository fills the profile it sees stored, which a second update would come from
        let profileRepository: ProfileRepository = injector.getInjected(identifiedBy: Injected.profileRepository)
        let profileSyncedExpectation = XCTestExpectation(description: "Stored profile synced by the profile repository")
        profileRepository.profileSyncResultPublisher.first().sink {
            if case .success = $0 { profileSyncedExpectation.fulfill() }
        }.store(in: &storage)

        mockUserService.injectNextGetJwtFromClientResponse(clientUserJwtResponse())
        // Two answers, so that a second update shows in the count rather than as a missing response. The update of
        // the connection is held until the test has checked what is stored while it is in flight.
        mockUserService.injectNextUpdateProfileResponse(clientUserUpdatedProfileResponse())
        mockUserService.injectNextUpdateProfileResponse(clientUserUpdatedProfileResponse())
        mockUserService.holdUpdateProfile()
        defer { mockUserService.releaseUpdateProfile() }

        let connection = Task {
            try await connectionRepository.connectUser(
                .init(userId: "clientUser", profile: .init(nickname: "ClientNickname", bio: nil, picture: nil)),
                tokenProvider: { "CLIENT_TOKEN" })
        }
        try await TaskUtils.wait(for: mockUserService.updateProfileCallCount >= 1, timeout: 5)
        // Nothing stored yet, so nothing for the profile repository to send again. Checked here rather than by the
        // count: its update could join the one in flight, or be sent only after the count is read.
        let storedProfileRead = XCTestExpectation(description: "Stored profile read")
        let storedProfile = Locked<StorableCurrentUserProfile?>(nil)
        userProfileDatabase.profilePublisher(userId: "clientUserId").first().sink {
            storedProfile.value = $0
            storedProfileRead.fulfill()
        }.store(in: &storage)
        await fulfillment(of: [storedProfileRead], timeout: 5)
        XCTAssertNil(storedProfile.value, "The profile must not be stored while its update is in flight")
        mockUserService.releaseUpdateProfile()
        try await connection.value

        // once the profile repository has synced the stored profile, rather than after an arbitrary delay
        await fulfillment(of: [updatedProfileExpectation, profileSyncedExpectation], timeout: 5)
        XCTAssertEqual(mockUserService.updateProfileCallCount, 1)
    }

    /// Regression: a hard authentication failure on a guest must NOT destroy and re-forge the guest
    /// identity. That churn inflated iOS user_id counts (~7x vs Android). The existing guest must be
    /// preserved as-is — no new guest minted (aligns iOS with Android's `!isGuest` guard).
    func testGuestIdentityPreservedOnAuthenticatedCallFailure() async throws {
        // Precondition: connected as guest
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "guestProfileId", userId: "guestUserId", nickname: "Guest", isGuest: true))

        let connectedExpectation = XCTestExpectation(description: "Connected as guest")
        let connectionRepository = makeConnectionRepository { state in
            if case let .connected(user, nil) = state, user.profile.isGuest {
                connectedExpectation.fulfill()
            }
        }
        await fulfillment(of: [connectedExpectation], timeout: 5)

        // Any churn would call getGuestJwt and mint a *different* guest.
        mockUserService.injectNextGetGuestJwtResponse(.with {
            $0.result = .success(.with {
                $0.jwt = "newJWT"
                $0.userID = "newGuestUserId"
                $0.profile = .with {
                    $0.id = "newGuestProfileId"
                    $0.nickname = "Guest"
                    $0.isGuest = true
                }
            })
        })

        // Act: a hard authentication failure occurs.
        try await connectionRepository.onAuthenticatedCallFailed()

        // Assert: the guest identity is preserved — same user id, no new guest minted.
        XCTAssertEqual(userDataStorage.userData?.id, "guestUserId")
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, 0)
    }

    /// When the exchange of the client token fails, the SDK keeps the guest session but remembers the client
    /// user, to connect them later. A `disconnectUser()` in that state must forget the client user: it used to
    /// keep them, and the reconnection that follows a disconnect then signed that very user in.
    func testDisconnectUserFromAGuestFallbackForgetsTheClientUser() async throws {
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "guestProfileId", userId: "guestUserId", nickname: "Guest", isGuest: true))

        let guestExpectation = XCTestExpectation(description: "Connected as guest")
        let clientUserConnectedExpectation = XCTestExpectation(description: "Client user connected")
        clientUserConnectedExpectation.isInverted = true
        let connectionRepository = makeConnectionRepository { state in
            guard case let .connected(user, _) = state else { return }
            if user.profile.isGuest {
                guestExpectation.fulfill()
            } else {
                clientUserConnectedExpectation.fulfill()
            }
        }
        await fulfillment(of: [guestExpectation], timeout: 5)

        // The exchange fails: the session stays a guest, with the client user remembered.
        mockUserService.injectNextGetJwtFromClientResponse(.with {
            $0.result = .fail(.with { $0.errors = [] })
        })
        try? await connectionRepository.connectUser(
            .init(userId: "clientUserId", profile: .init(nickname: "Client", bio: nil, picture: nil)),
            tokenProvider: { "CLIENT_TOKEN" })
        XCTAssertEqual(userDataStorage.clientUserData?.id, "clientUserId")
        XCTAssertEqual(userDataStorage.userData?.id, "guestUserId")

        // The next exchange would succeed: a disconnect that kept the client user would use it.
        mockUserService.injectNextGetJwtFromClientResponse(.with {
            $0.result = .success(.with {
                $0.jwt = "clientJWT"
                $0.userID = "clientOctopusUserId"
                $0.profile = .with {
                    $0.id = "clientProfileId"
                    $0.nickname = "Client"
                    $0.isGuest = false
                }
            })
        })

        try await connectionRepository.disconnectUser()

        await fulfillment(of: [clientUserConnectedExpectation], timeout: 1)
        XCTAssertNil(userDataStorage.clientUserData)
        // Already a guest: the guest identity is kept, no new guest is minted.
        XCTAssertEqual(userDataStorage.userData?.id, "guestUserId")
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, 0)
    }

    /// A client user refused as banned leaves the guest session carrying their ban. Once a disconnect has
    /// forgotten that client user, the guest must not be told they are banned any more.
    func testDisconnectUserFromAGuestFallbackClearsTheClientUserBan() async throws {
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "guestProfileId", userId: "guestUserId", nickname: "Guest", isGuest: true))

        let guestExpectation = XCTestExpectation(description: "Connected as guest")
        let connectionRepository = makeConnectionRepository { state in
            if case let .connected(user, nil) = state, user.profile.isGuest {
                guestExpectation.fulfill()
            }
        }
        await fulfillment(of: [guestExpectation], timeout: 5)

        mockUserService.injectNextGetJwtFromClientResponse(.with {
            $0.result = .fail(.with {
                $0.errors = [.with {
                    $0.errorCode = .userBanned
                    $0.message = "You have been banned"
                }]
            })
        })
        try? await connectionRepository.connectUser(
            .init(userId: "clientUserId", profile: .init(nickname: "Client", bio: nil, picture: nil)),
            tokenProvider: { "CLIENT_TOKEN" })
        XCTAssertEqual(connectionRepository.connectionState.userBannedMessage, "You have been banned")

        try await connectionRepository.disconnectUser()

        XCTAssertNil(connectionRepository.connectionState.userBannedMessage)
        XCTAssertNil(userDataStorage.clientUserData)
        guard case let .connected(user, nil) = connectionRepository.connectionState else {
            XCTFail("State is \(connectionRepository.connectionState), expected the guest without error")
            return
        }
        XCTAssertEqual(user.profile.userId, "guestUserId")
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, 0)
    }

    /// `logout()` is also reached without `disconnectUser()`: on a community switch, when the server no longer
    /// knows the profile, or when another client user signs in. On a guest session that still remembers a client
    /// user, it must forget that client user and keep the guest.
    func testLogoutOnGuestForgetsTheRememberedClientUser() async throws {
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "guestProfileId", userId: "guestUserId", nickname: "Guest", isGuest: true))
        userDataStorage.store(clientUserData: .init(id: "clientUserId"))

        let guestExpectation = XCTestExpectation(description: "Connected as guest")
        let connectionRepository = makeConnectionRepository { state in
            if case let .connected(user, nil) = state, user.profile.isGuest {
                guestExpectation.fulfill()
            }
        }
        await fulfillment(of: [guestExpectation], timeout: 5)

        try await connectionRepository.logout()

        XCTAssertNil(userDataStorage.clientUserData)
        XCTAssertEqual(userDataStorage.userData?.id, "guestUserId")
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, 0)
    }

    /// A guest has no account to log out from: `logout()` must be a no-op for a guest (matching
    /// Android's `!isGuest` guard), preserving the guest identity instead of destroying it.
    func testLogoutOnGuestPreservesIdentity() async throws {
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "guestProfileId", userId: "guestUserId", nickname: "Guest", isGuest: true))

        let connectedExpectation = XCTestExpectation(description: "Connected as guest")
        let connectionRepository = makeConnectionRepository { state in
            if case let .connected(user, nil) = state, user.profile.isGuest {
                connectedExpectation.fulfill()
            }
        }
        await fulfillment(of: [connectedExpectation], timeout: 5)

        try await connectionRepository.logout()

        // The guest identity must survive an explicit logout.
        XCTAssertEqual(userDataStorage.userData?.id, "guestUserId")
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, 0)
    }

    /// A guest JWT is only valid on the community that issued it, and the session is stored in a Keychain service
    /// shared by every community: kept across a community switch, it would be read by the next community's core
    /// and rejected by its server. The switch drops it, without forging a guest on the community being left.
    func testLogoutBeforeCommunitySwitchOnGuestDropsTheGuestSession() async throws {
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "guestProfileId", userId: "guestUserId", nickname: "Guest", isGuest: true))
        userDataStorage.store(clientUserData: .init(id: "clientUserId"))

        let guestExpectation = XCTestExpectation(description: "Connected as guest")
        let connectionRepository = makeConnectionRepository { state in
            if case let .connected(user, nil) = state, user.profile.isGuest {
                guestExpectation.fulfill()
            }
        }
        await fulfillment(of: [guestExpectation], timeout: 5)

        try await connectionRepository.logoutBeforeCommunitySwitch()

        XCTAssertNil(userDataStorage.userData)
        XCTAssertNil(userDataStorage.clientUserData)
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, 0)
    }

    /// The switch logs a client user out as `logout()` does.
    func testLogoutBeforeCommunitySwitchOnClientUserDropsTheSession() async throws {
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "profileId", userId: "userId", nickname: "Guest", isGuest: true))

        let guestExpectation = XCTestExpectation(description: "Connected as guest")
        let clientExpectation = XCTestExpectation(description: "Connected as client user")
        let connectionRepository = makeConnectionRepository { state in
            guard case let .connected(user, nil) = state else { return }
            if user.profile.isGuest {
                guestExpectation.fulfill()
            } else {
                clientExpectation.fulfill()
            }
        }
        await fulfillment(of: [guestExpectation], timeout: 5)

        mockUserService.injectNextGetJwtFromClientResponse(.with {
            $0.result = .success(.with {
                $0.jwt = "fakeJWT"
                $0.userID = "userId"
                $0.profile = .with {
                    $0.id = "profileId"
                    $0.nickname = "ClientNickName"
                    $0.hasSeenOnboarding_p = false
                    $0.hasAcceptedCgu_p = false
                    $0.hasConfirmedNickname_p = false
                    $0.isGuest = false
                }
            })
        })
        try await connectionRepository.connectUser(
            .init(userId: "clientUserId", profile: .init(nickname: "ClientNickName", bio: nil, picture: nil)),
            tokenProvider: { "CLIENT_TOKEN" })
        await fulfillment(of: [clientExpectation], timeout: 5)

        try await connectionRepository.logoutBeforeCommunitySwitch()

        XCTAssertNil(userDataStorage.userData)
        XCTAssertNil(userDataStorage.clientUserData)
    }

    // MARK: Community closure

    /// While the community is closed, connecting a user keeps them, without the exchange that would be a call: it is
    /// done once the community reopens.
    func testConnectingWhileClosedKeepsTheUserWithoutExchanging() async throws {
        try await setupWithNonConnectedWithoutErrorState()
        await closeCommunity()
        let connectionRepository = SSOConnectionRepository(connectionMode: connectionMode, injector: injector)

        try await connectClientUser(connectionRepository)

        XCTAssertEqual(userDataStorage.clientUserData?.id, "clientUser")
        XCTAssertEqual(mockUserService.getJwtCallCount, 0)
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, 0)
    }

    /// Another user connecting while the community is closed must not find the previous user's session when it
    /// reopens.
    func testConnectingAnotherUserWhileClosedDropsThePreviousSession() async throws {
        try await setupWithClientUserProfile(memberProfile(), clientUserId: "previousClientUser")
        await closeCommunity()
        let connectionRepository = SSOConnectionRepository(connectionMode: connectionMode, injector: injector)

        try await connectClientUser(connectionRepository)

        XCTAssertNil(userDataStorage.userData)
        XCTAssertEqual(userDataStorage.clientUserData?.id, "clientUser")
        XCTAssertEqual(mockUserService.getJwtCallCount, 0)
    }

    func testDisconnectingWhileClosedForgetsTheUserAndCreatesNoGuest() async throws {
        try await setupWithClientUserProfile(memberProfile(), clientUserId: "clientUser")
        await closeCommunity()
        let connectionRepository = SSOConnectionRepository(connectionMode: connectionMode, injector: injector)

        try await connectionRepository.disconnectUser()

        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertNil(userDataStorage.clientUserData)
        XCTAssertNil(userDataStorage.userData)
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, 0)
    }

    func testReopeningAfterAConnectExchangesTheToken() async throws {
        try await setupWithNonConnectedWithoutErrorState()
        await closeCommunity()
        let connectionRepository = SSOConnectionRepository(connectionMode: connectionMode, injector: injector)
        try await connectClientUser(connectionRepository)
        mockUserService.injectNextGetJwtFromClientResponse(clientUserJwtResponse())

        await reopenCommunity()
        connectionRepository.resumeAfterCommunityReopening()

        try await TaskUtils.wait(for: self.userDataStorage.userData?.clientId == "clientUser", timeout: 3)
        XCTAssertEqual(mockUserService.getJwtCallCount, 1)
    }

    /// A first launch on a closed community has no session: a guest is connected once it reopens.
    func testReopeningWithNoSessionConnectsAGuest() async throws {
        try await setupWithNonConnectedWithoutErrorState()
        await closeCommunity()
        let connectionRepository = SSOConnectionRepository(connectionMode: connectionMode, injector: injector)
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, 0)
        injectNewGuestResponse()

        await reopenCommunity()
        connectionRepository.resumeAfterCommunityReopening()

        try await TaskUtils.wait(for: self.mockUserService.getGuestJwtCallCount == 1, timeout: 3)
    }

    /// The session kept through the closure is still the user's: nothing to connect again.
    func testReopeningWithAKeptSessionDoesNotConnect() async throws {
        storeClientSessionWithoutProfile()
        await closeCommunity()
        let connectionRepository = SSOConnectionRepository(connectionMode: connectionMode, injector: injector)

        await reopenCommunity()
        connectionRepository.resumeAfterCommunityReopening()

        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(mockUserService.getJwtCallCount, 0)
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, 0)
    }

    /// Before the SDK knows the community is closed, the connections can leave: the server refuses them. Nothing is
    /// stored then, and the client user is kept, so that the reopening connects them.
    func testRefusedConnectionsOfAClosedKeyStoreNothingAndKeepTheClientUser() async throws {
        try await setupWithNonConnectedWithoutErrorState()
        mockUserService.getJwtError = .permissionDenied(reason: "Closed msg")
        mockUserService.getGuestJwtError = .permissionDenied(reason: "Closed msg")
        let connectionRepository = SSOConnectionRepository(connectionMode: connectionMode, injector: injector)

        try? await connectClientUser(connectionRepository)

        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertNil(userDataStorage.userData)
        XCTAssertEqual(userDataStorage.clientUserData?.id, "clientUser")
        XCTAssertEqual(mockUserService.getJwtCallCount, 1)
    }

    // MARK: Banned member whose exchange succeeds

    /// The server lets the exchange of a banned member go through, with a token that only reads the access: the
    /// ban is then told by the access, and has to reach the host app as it did when the exchange failed.
    func testBannedMemberWhoseExchangeSucceedsIsReportedAsUserBanned() async throws {
        let connectionRepository = try await makeRepositoryConnectedAsGuest()
        let guestJwtCallCount = mockUserService.getGuestJwtCallCount

        try await connectBannedClientUser(connectionRepository, message: "You have been banned")

        XCTAssertEqual(connectionRepository.connectionState.userBannedMessage, "You have been banned")
        XCTAssertEqual(mockUserService.updateProfileCallCount, 0)
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, guestJwtCallCount)
        // The session of the banned member is stored
        XCTAssertEqual(userDataStorage.userData?.id, "clientUserId")
        XCTAssertEqual(userDataStorage.userData?.clientId, "clientUser")
    }

    func testBannedMemberWithoutServerMessageGetsTheComposedSentence() async throws {
        let connectionRepository = try await makeRepositoryConnectedAsGuest()

        try await connectBannedClientUser(
            connectionRepository, message: "", nickname: "marie_l92",
            expectedMessage: "Your account @marie_l92 was banned for breaking the “Job applications” policy.")
        try await connectBannedClientUser(
            connectionRepository, message: "", nickname: nil,
            expectedMessage: "Your account was banned for breaking the “Job applications” policy.")
    }

    func testExcludedDeletedOrGrantedAccessAfterTheExchangeConnectsAsBefore() async throws {
        let accesses: [Com_Octopuscommunity_CanAccessCommunityResponse] = [
            .with {
                $0.canAccessCommunity = false
                $0.memberExcluded = .init()
            },
            .with {
                $0.canAccessCommunity = false
                $0.accountDeleted = .init()
            },
            .with { $0.canAccessCommunity = true }
        ]
        let connectionRepository = try await makeRepositoryConnectedAsGuest()
        for access in accesses {
            mockUserService.injectNextGetJwtFromClientResponse(clientUserJwtResponse())
            mockUserService.injectNextCanAccessCommunityResponse(access)
            // The update of the profile is refused to a member without access, as the server does
            mockUserService.injectNextUpdateProfileError(.permissionDenied(reason: nil))

            do {
                try await connectClientUser(connectionRepository)
            } catch ConnectionError.communityAccessDenied {
                // what a member without access gets today
            }

            XCTAssertNil(connectionRepository.connectionState.userBannedMessage)
            let storedProfile = await storedProfile(userId: "clientUserId")
            XCTAssertEqual(storedProfile?.id, "clientProfileId")
            try await connectionRepository.logout()
            try? await TaskUtils.wait(for: userDataStorage.userData == nil, timeout: 2)
        }
    }

    func testAFailingAccessCallAfterTheExchangeDoesNotFailTheConnection() async throws {
        let connectionRepository = try await makeRepositoryConnectedAsGuest()
        mockUserService.injectNextGetJwtFromClientResponse(clientUserJwtResponse())
        mockUserService.injectNextCanAccessCommunityError(.timeout)
        mockUserService.injectNextUpdateProfileResponse(clientUserUpdatedProfileResponse())

        try await connectClientUser(connectionRepository)

        XCTAssertNil(connectionRepository.connectionState.userBannedMessage)
        XCTAssertEqual(userDataStorage.userData?.id, "clientUserId")
    }

    /// The banned member has a session: once their profile is loaded, the state shows their account. It must keep
    /// telling they are banned, since the actions of a banned member are blocked on that message.
    func testTheBanStateSurvivesTheBannedMemberProfileBeingLoaded() async throws {
        let connectionRepository = try await makeRepositoryConnectedAsGuest()
        try await connectBannedClientUser(connectionRepository, message: "You have been banned")

        try await userProfileDatabase.upsert(profile: StorableCurrentUserProfile.create(
            id: "clientProfileId", userId: "clientUserId", nickname: "Banned", isGuest: false))

        try await TaskUtils.wait(for: {
            if case let .connected(user, _) = connectionRepository.connectionState { return !user.profile.isGuest }
            return false
        }(), timeout: 5)
        XCTAssertEqual(connectionRepository.connectionState.userBannedMessage, "You have been banned")
    }

    // MARK: Banned member after a relaunch

    /// The banned member has a stored session, so the next launch makes no exchange, and the error of the ban,
    /// only kept in memory, is gone: the stored access tells the ban again.
    func testAStoredBanFeedsTheBanStateAfterARelaunch() async throws {
        let connectionRepository = try await makeRepositoryRelaunchedWithABannedMember()

        XCTAssertEqual(connectionRepository.connectionState.userBannedMessage, "You have been banned")
    }

    func testConnectUserAfterARelaunchStillReportsTheStoredBan() async throws {
        let connectionRepository = try await makeRepositoryRelaunchedWithABannedMember()
        let accessCallCount = mockUserService.canAccessCommunityCallCount
        mockUserService.injectNextCanAccessCommunityResponse(bannedAccessResponse(message: "You have been banned"))

        await assertConnectUserReportsBan(connectionRepository, message: "You have been banned")

        XCTAssertEqual(mockUserService.getJwtCallCount, 0)
        XCTAssertEqual(mockUserService.updateProfileCallCount, 0)
        XCTAssertEqual(mockUserService.canAccessCommunityCallCount, accessCallCount + 1)
        XCTAssertEqual(connectionRepository.connectionState.userBannedMessage, "You have been banned")
    }

    func testConnectUserAfterARelaunchWithAChangedClientProfileReportsTheBanNotAnAccessDenial() async throws {
        let connectionRepository = try await makeRepositoryRelaunchedWithABannedMember()
        mockUserService.injectNextCanAccessCommunityResponse(bannedAccessResponse(message: "You have been banned"))

        await assertConnectUserReportsBan(connectionRepository, message: "You have been banned",
                                          nickname: "AnotherNickname")

        XCTAssertEqual(mockUserService.updateProfileCallCount, 0)
    }

    func testConnectUserAfterARelaunchUsesTheAccessJustReadWhenTheBanWasLifted() async throws {
        let connectionRepository = try await makeRepositoryRelaunchedWithABannedMember()
        mockUserService.injectNextCanAccessCommunityResponse(.with { $0.canAccessCommunity = true })

        try await connectClientUser(connectionRepository)

        XCTAssertNil(connectionRepository.connectionState.userBannedMessage)
        XCTAssertEqual(mockUserService.getJwtCallCount, 0, "a lifted ban needs no new token")
    }

    /// The access just read is the one to go by: the published one still says banned for a main queue turn.
    func testConnectUserAfterARelaunchWithALiftedBanSendsTheChangedClientProfile() async throws {
        let connectionRepository = try await makeRepositoryRelaunchedWithABannedMember()
        mockUserService.injectNextCanAccessCommunityResponse(.with { $0.canAccessCommunity = true })
        mockUserService.injectNextUpdateProfileResponse(clientUserUpdatedProfileResponse())

        try await connectionRepository.connectUser(
            .init(userId: "clientUser", profile: .init(nickname: "AnotherNickname", bio: nil, picture: nil)),
            tokenProvider: { "CLIENT_TOKEN" })

        XCTAssertNil(connectionRepository.connectionState.userBannedMessage)
        XCTAssertEqual(mockUserService.getJwtCallCount, 0)
    }

    /// The token of a session is renewed by any call: a renewed token is still the session of the deleted account.
    func testReturnAfterAccountDeletionStillRunsWhenTheTokenIsRenewedMeanwhile() async throws {
        let connectionRepository = try await makeRepositoryWithADeletedAccount()
        mockUserService.getJwtError = .timeout
        injectNewGuestResponse()
        let userDataStorage = userDataStorage
        mockUserService.getJwtHook = {
            userDataStorage.store(userData: .init(id: "clientUserId", clientId: "clientUser",
                                                  jwtToken: "renewedJwt"))
        }

        try await connectionRepository.reconnectAfterAccountDeletion()

        XCTAssertEqual(userDataStorage.userData?.id, "newGuestUserId")
    }

    func testConnectUserAfterARelaunchKeepsTheStoredBanWhenTheAccessCannotBeRead() async throws {
        let connectionRepository = try await makeRepositoryRelaunchedWithABannedMember()
        mockUserService.injectNextCanAccessCommunityError(.timeout)

        await assertConnectUserReportsBan(connectionRepository, message: "You have been banned")
    }

    func testAStoredBanWithoutMessageUsesTheComposedSentence() async throws {
        let connectionRepository = try await makeRepositoryRelaunchedWithABannedMember(message: nil)

        XCTAssertEqual(connectionRepository.connectionState.userBannedMessage,
                       "Your account @marie_l92 was banned for breaking the “Job applications” policy.")
    }

    func testALiftedBanClearsTheBanState() async throws {
        let connectionRepository = try await makeRepositoryRelaunchedWithABannedMember()

        try await userConfigDatabase.upsert(UserConfig(canAccessCommunity: true, accessDeniedMessage: nil))

        try await TaskUtils.wait(for: connectionRepository.connectionState.userBannedMessage == nil, timeout: 5)
        guard case .connected = connectionRepository.connectionState else {
            return XCTFail("State is \(connectionRepository.connectionState), expected the member still connected")
        }
    }

    /// A guest is not the banned member: the row of a previous member's ban says nothing about them.
    func testAStoredBanDoesNotMarkAGuestSession() async throws {
        try await storeBannedAccess(message: "You have been banned")

        let connectionRepository = try await makeRepositoryConnectedAsGuest()

        // leave the stored access the time to be delivered
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertNil(connectionRepository.connectionState.userBannedMessage)
    }

    private func storeBannedAccess(message: String?) async throws {
        let banned = UserConfig(
            canAccessCommunity: false, accessDeniedMessage: message,
            noAccessReason: .accountBanned(.init(nickname: "marie_l92", policyName: "Job applications",
                                                 policyDescription: "Desc", contactEmail: nil)))
        try await userConfigDatabase.upsert(banned)
        let configRepository: ConfigRepository = injector.getInjected(identifiedBy: Injected.configRepository)
        try await TaskUtils.wait(for: configRepository.userConfig == banned, timeout: 2)
    }

    /// A repository built as a launch following the ban of the member "clientUser" builds it: their session, their
    /// profile, their client profile ("ClientNickname") and the access telling the ban are stored. Returned once
    /// the state shows their account.
    private func makeRepositoryRelaunchedWithABannedMember(message: String? = "You have been banned")
    async throws -> SSOConnectionRepository {
        storeClientSessionWithoutProfile()
        try await userProfileDatabase.upsert(profile: StorableCurrentUserProfile.create(
            id: "clientProfileId", userId: "clientUserId", nickname: "ClientNickname", isGuest: false))
        try await injector.getInjected(identifiedBy: Injected.clientUserProfileDatabase).upsert(
            profile: .init(nickname: "ClientNickname", bio: nil, picture: nil), clientUserId: "clientUser")
        try await storeBannedAccess(message: message)

        let connectedExpectation = XCTestExpectation(description: "Member connected")
        connectedExpectation.assertForOverFulfill = false
        let connectionRepository = makeConnectionRepository { state in
            if case let .connected(user, _) = state, !user.profile.isGuest, state.userBannedMessage != nil {
                connectedExpectation.fulfill()
            }
        }
        await fulfillment(of: [connectedExpectation], timeout: 5)
        return connectionRepository
    }

    /// Connects the client user "clientUser" again and checks that `connectUser` reports the ban.
    private func assertConnectUserReportsBan(_ connectionRepository: SSOConnectionRepository, message: String,
                                             nickname: String = "ClientNickname",
                                             file: StaticString = #filePath, line: UInt = #line) async {
        do {
            try await connectionRepository.connectUser(
                .init(userId: "clientUser", profile: .init(nickname: nickname, bio: nil, picture: nil)),
                tokenProvider: { "CLIENT_TOKEN" })
            XCTFail("connectUser should have thrown the ban", file: file, line: line)
        } catch {
            guard case let ConnectionError.detailedErrors(errors) = error else {
                return XCTFail("Expected the ban, got \(error)", file: file, line: line)
            }
            XCTAssertEqual(errors.first?.reason, .userBanned, file: file, line: line)
            XCTAssertEqual(errors.first?.message, message, file: file, line: line)
        }
    }

    // MARK: Return after an account deletion

    /// The deleted account is not linked to the client user any more: the exchange of their token, sent without
    /// the token of the deleted account, gives them a new account.
    func testReturnAfterAccountDeletionExchangesTheClientTokenWithoutAGuest() async throws {
        let connectionRepository = try await makeRepositoryWithADeletedAccount()
        let guestJwtCallCount = mockUserService.getGuestJwtCallCount
        let accessCallCount = mockUserService.canAccessCommunityCallCount
        injectDeletedAccessResponse()
        mockUserService.injectNextGetJwtFromClientResponse(newAccountJwtResponse())
        mockUserService.injectNextCanAccessCommunityResponse(.with { $0.canAccessCommunity = true })

        try await connectionRepository.reconnectAfterAccountDeletion()

        XCTAssertEqual(userDataStorage.userData?.id, "newUserId")
        XCTAssertEqual(userDataStorage.userData?.clientId, "clientUser")
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, guestJwtCallCount)
        XCTAssertEqual(mockUserService.getJwtAuthenticatedFlags.last, false)
        // one read before the return, one with the new session
        XCTAssertEqual(mockUserService.canAccessCommunityCallCount, accessCallCount + 2)
    }

    /// The token provider only lives in memory: after a relaunch without `connectUser`, there is nothing to
    /// exchange.
    func testReturnAfterAccountDeletionWithoutATokenProviderConnectsAGuest() async throws {
        let firstRepository = try await makeRepositoryWithADeletedAccount()
        withExtendedLifetime(firstRepository) { }
        let connectionRepository = SSOConnectionRepository(connectionMode: connectionMode, injector: injector)
        try await TaskUtils.wait(for: connectionRepository.connectionState.user != nil, timeout: 5)
        let jwtCallCount = mockUserService.getJwtCallCount
        injectNewGuestResponse()

        try await connectionRepository.reconnectAfterAccountDeletion()

        XCTAssertEqual(mockUserService.getJwtCallCount, jwtCallCount)
        XCTAssertEqual(userDataStorage.userData?.id, "newGuestUserId")
        XCTAssertNil(userDataStorage.userData?.clientId)
        XCTAssertNotNil(userDataStorage.clientUserData)
    }

    func testReturnAfterAccountDeletionWithoutAClientUserConnectsAGuest() async throws {
        let connectionRepository = try await makeRepositoryWithADeletedAccount()
        userDataStorage.store(clientUserData: nil)
        let jwtCallCount = mockUserService.getJwtCallCount
        injectNewGuestResponse()

        try await connectionRepository.reconnectAfterAccountDeletion()

        XCTAssertEqual(mockUserService.getJwtCallCount, jwtCallCount)
        XCTAssertEqual(userDataStorage.userData?.id, "newGuestUserId")
    }

    func testReturnAfterAccountDeletionFallsBackToAGuestWhenTheExchangeFails() async throws {
        let connectionRepository = try await makeRepositoryWithADeletedAccount()
        mockUserService.getJwtError = .timeout
        injectNewGuestResponse()

        try await connectionRepository.reconnectAfterAccountDeletion()

        XCTAssertEqual(userDataStorage.userData?.id, "newGuestUserId")
        XCTAssertNotNil(userDataStorage.clientUserData, "the client user is kept for the next connectUser")
    }

    /// The member must stay on the screen, able to tap again, when nothing gets them a session.
    func testReturnAfterAccountDeletionKeepsTheSessionWhenNothingSucceeds() async throws {
        let connectionRepository = try await makeRepositoryWithADeletedAccount()
        let deletedSession = userDataStorage.userData
        mockUserService.getJwtError = .timeout
        mockUserService.getGuestJwtError = .timeout

        do {
            try await connectionRepository.reconnectAfterAccountDeletion()
            XCTFail("The return should have thrown")
        } catch { }

        XCTAssertEqual(userDataStorage.userData, deletedSession)
        let configRepository: ConfigRepository = injector.getInjected(identifiedBy: Injected.configRepository)
        XCTAssertEqual(configRepository.userConfig?.noAccessReason, .accountDeleted)

        mockUserService.getJwtError = nil
        mockUserService.getGuestJwtError = nil
        injectDeletedAccessResponse()
        mockUserService.injectNextGetJwtFromClientResponse(newAccountJwtResponse())
        mockUserService.injectNextCanAccessCommunityResponse(.with { $0.canAccessCommunity = true })

        try await connectionRepository.reconnectAfterAccountDeletion()

        XCTAssertEqual(userDataStorage.userData?.id, "newUserId")
    }

    func testReturnAfterAccountDeletionWithoutNetworkThrowsNoNetworkAndCallsNothing() async throws {
        let connectionRepository = try await makeRepositoryWithADeletedAccount()
        let jwtCallCount = mockUserService.getJwtCallCount
        let guestJwtCallCount = mockUserService.getGuestJwtCallCount
        (injector.getInjected(identifiedBy: Injected.networkMonitor) as! MockNetworkMonitor)
            .connectionAvailable = false

        do {
            try await connectionRepository.reconnectAfterAccountDeletion()
            XCTFail("The return should have thrown")
        } catch {
            guard case ConnectionError.noNetwork = error else { return XCTFail("Expected noNetwork, got \(error)") }
        }

        XCTAssertEqual(mockUserService.getJwtCallCount, jwtCallCount)
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, guestJwtCallCount)
        XCTAssertEqual(userDataStorage.userData?.id, "clientUserId")
    }

    func testReturnAfterAccountDeletionBannedSurfacesTheBanWithoutAGuest() async throws {
        let connectionRepository = try await makeRepositoryWithADeletedAccount()
        let guestJwtCallCount = mockUserService.getGuestJwtCallCount
        mockUserService.injectNextGetJwtFromClientResponse(.with {
            $0.result = .fail(.with {
                $0.errors = [.with {
                    $0.errorCode = .userBanned
                    $0.message = "Banned"
                }]
            })
        })

        do {
            try await connectionRepository.reconnectAfterAccountDeletion()
            XCTFail("The return should have thrown the ban")
        } catch {
            guard case let ConnectionError.detailedErrors(errors) = error else {
                return XCTFail("Expected the ban, got \(error)")
            }
            XCTAssertEqual(errors.first?.reason, .userBanned)
        }

        XCTAssertEqual(connectionRepository.connectionState.userBannedMessage, "Banned")
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, guestJwtCallCount)
    }

    func testReturnAfterAccountDeletionDeletesTheDeletedAccountProfile() async throws {
        let connectionRepository = try await makeRepositoryWithADeletedAccount()
        injectDeletedAccessResponse()
        mockUserService.injectNextGetJwtFromClientResponse(newAccountJwtResponse())
        mockUserService.injectNextCanAccessCommunityResponse(.with { $0.canAccessCommunity = true })

        try await connectionRepository.reconnectAfterAccountDeletion()

        let deletedAccountProfile = await storedProfile(userId: "clientUserId")
        XCTAssertNil(deletedAccountProfile)
        let newAccountProfile = await storedProfile(userId: "newUserId")
        XCTAssertEqual(newAccountProfile?.id, "newProfileId")
    }

    /// The stored reason can be late: a first return whose read of the access failed leaves it. The exchange then
    /// gives back the account the member already has, which is theirs to keep, with its profile.
    func testReturnAfterAccountDeletionKeepsAnAccountTheExchangeGivesBack() async throws {
        let connectionRepository = try await makeRepositoryWithADeletedAccount()
        let guestJwtCallCount = mockUserService.getGuestJwtCallCount
        // the read before the return fails too: the stored reason is all the return has
        mockUserService.injectNextCanAccessCommunityError(.timeout)
        mockUserService.injectNextGetJwtFromClientResponse(clientUserJwtResponse())
        mockUserService.injectNextCanAccessCommunityResponse(.with { $0.canAccessCommunity = true })
        mockUserService.injectNextUpdateProfileResponse(clientUserUpdatedProfileResponse())

        try await connectionRepository.reconnectAfterAccountDeletion()

        XCTAssertEqual(userDataStorage.userData?.id, "clientUserId")
        XCTAssertEqual(userDataStorage.userData?.clientId, "clientUser")
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, guestJwtCallCount)
        let keptProfile = await storedProfile(userId: "clientUserId")
        XCTAssertEqual(keptProfile?.id, "clientProfileId")
    }

    /// A double tap, or two screens asking together: one exchange, and no guest on top of it.
    func testReturnsAfterAccountDeletionRunningTogetherExchangeOnce() async throws {
        let connectionRepository = try await makeRepositoryWithADeletedAccount()
        let jwtCallCount = mockUserService.getJwtCallCount
        let guestJwtCallCount = mockUserService.getGuestJwtCallCount
        injectDeletedAccessResponse()
        mockUserService.injectNextGetJwtFromClientResponse(newAccountJwtResponse())
        mockUserService.injectNextCanAccessCommunityResponse(.with { $0.canAccessCommunity = true })

        async let first: Void = connectionRepository.reconnectAfterAccountDeletion()
        async let second: Void = connectionRepository.reconnectAfterAccountDeletion()
        _ = try await (first, second)

        XCTAssertEqual(mockUserService.getJwtCallCount, jwtCallCount + 1)
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, guestJwtCallCount)
        XCTAssertEqual(userDataStorage.userData?.id, "newUserId")
    }

    /// The stored reason can be late, and a tap can come from a screen about to leave: the access is read first,
    /// and a session that has its access is left as it is.
    func testReturnAfterAccountDeletionDoesNothingWhenTheAccessIsBack() async throws {
        let connectionRepository = try await makeRepositoryWithADeletedAccount()
        let jwtCallCount = mockUserService.getJwtCallCount
        let guestJwtCallCount = mockUserService.getGuestJwtCallCount
        mockUserService.injectNextCanAccessCommunityResponse(.with { $0.canAccessCommunity = true })

        try await connectionRepository.reconnectAfterAccountDeletion()

        XCTAssertEqual(mockUserService.getJwtCallCount, jwtCallCount)
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, guestJwtCallCount)
        XCTAssertEqual(userDataStorage.userData?.id, "clientUserId")
        let keptProfile = await storedProfile(userId: "clientUserId")
        XCTAssertEqual(keptProfile?.id, "clientProfileId")
        let configRepository: ConfigRepository = injector.getInjected(identifiedBy: Injected.configRepository)
        XCTAssertEqual(configRepository.userConfig?.canAccessCommunity, true)
    }

    // MARK: Ended session

    /// The guest a banned device was given gets a new guest once a read of the access says the server ended its
    /// session, without anything asked of the user, and once only.
    func testAnEndedGuestSessionIsReplacedByANewGuest() async throws {
        let connectionRepository = try await makeRepositoryConnectedAsGuest()
        let jwtCallCount = mockUserService.getJwtCallCount
        let guestJwtCallCount = mockUserService.getGuestJwtCallCount
        injectEndedSessionAccessResponse()
        injectNewGuestResponse()
        mockUserService.injectNextCanAccessCommunityResponse(.with { $0.canAccessCommunity = true })

        do throws(ServerCallError) {
            try await sharedConfigRepository().refreshCommunityAccess()
            XCTFail("an ended session is no access")
        } catch {
            XCTAssertTrue(error.isSessionEnded)
        }

        try await TaskUtils.wait(for: userDataStorage.userData?.id == "newGuestUserId", timeout: 5)
        XCTAssertNil(userDataStorage.userData?.clientId)
        XCTAssertEqual(mockUserService.getJwtCallCount, jwtCallCount)
        try await TaskUtils.wait(for: sharedConfigRepository().userConfig?.canAccessCommunity == true, timeout: 5)
        // leave a second replacement the time to happen
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, guestJwtCallCount + 1)
        XCTAssertNil(connectionRepository.connectionState.userBannedMessage)
    }

    /// A member signed in on a banned device was given that guest too: once its session is ended, the exchange of
    /// their token, sent without the token of the ended session, gives them their account.
    func testAnEndedSessionOfAClientUserIsReplacedByAnExchange() async throws {
        let connectionRepository = try await makeRepositoryWithADeletedAccount()
        let guestJwtCallCount = mockUserService.getGuestJwtCallCount
        injectEndedSessionAccessResponse()
        mockUserService.injectNextGetJwtFromClientResponse(newAccountJwtResponse())
        mockUserService.injectNextCanAccessCommunityResponse(.with { $0.canAccessCommunity = true })

        _ = try? await sharedConfigRepository().refreshCommunityAccess()

        try await TaskUtils.wait(for: userDataStorage.userData?.id == "newUserId", timeout: 5)
        XCTAssertEqual(userDataStorage.userData?.clientId, "clientUser")
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, guestJwtCallCount)
        XCTAssertEqual(mockUserService.getJwtAuthenticatedFlags.last, false)
        withExtendedLifetime(connectionRepository) { }
    }

    /// A server that would end each new session at once is not asked for another in a loop: one replacement per
    /// interval, the next end is found again by a later read.
    func testAnEndedSessionIsReplacedAtMostOncePerInterval() async throws {
        let connectionRepository = try await makeRepositoryConnectedAsGuest()
        let guestJwtCallCount = mockUserService.getGuestJwtCallCount
        let accessCallCount = mockUserService.canAccessCommunityCallCount
        injectEndedSessionAccessResponse()
        injectNewGuestResponse()
        // the read of the new guest's access says it is over too
        injectEndedSessionAccessResponse()

        _ = try? await sharedConfigRepository().refreshCommunityAccess()

        try await TaskUtils.wait(for: mockUserService.canAccessCommunityCallCount == accessCallCount + 2,
                                 timeout: 5)
        // leave a second replacement the time to happen
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, guestJwtCallCount + 1)
        XCTAssertEqual(userDataStorage.userData?.id, "newGuestUserId")
        withExtendedLifetime(connectionRepository) { }
    }

    /// The member's session stored with their ban is the guest a banned device was given: once the account behind
    /// it is no longer banned, the read `connectUser` makes says the session is over. That is no ban to report: the
    /// session is replaced with the token provider just given.
    func testConnectUserReplacesTheEndedSessionOfABannedMember() async throws {
        let connectionRepository = try await makeRepositoryRelaunchedWithABannedMember()
        let jwtCallCount = mockUserService.getJwtCallCount
        let guestJwtCallCount = mockUserService.getGuestJwtCallCount
        injectEndedSessionAccessResponse()
        mockUserService.injectNextGetJwtFromClientResponse(newAccountJwtResponse())
        mockUserService.injectNextCanAccessCommunityResponse(.with { $0.canAccessCommunity = true })

        try await connectionRepository.connectUser(
            .init(userId: "clientUser", profile: .init(nickname: "ClientNickname", bio: nil, picture: nil)),
            tokenProvider: { "CLIENT_TOKEN" })

        XCTAssertEqual(userDataStorage.userData?.id, "newUserId")
        XCTAssertEqual(userDataStorage.userData?.clientId, "clientUser")
        // leave a second replacement the time to happen
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(mockUserService.getJwtCallCount, jwtCallCount + 1)
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, guestJwtCallCount)
        XCTAssertNil(connectionRepository.connectionState.userBannedMessage)
    }

    /// Before the app calls `connectUser` in this launch, there is no token provider: a guest would stand in for
    /// the member until `connectUser` exchanges again. The ended session waits for it instead.
    func testAMemberEndedSessionWaitsForConnectUser() async throws {
        let connectionRepository = try await makeRepositoryRelaunchedWithABannedMember()
        let guestJwtCallCount = mockUserService.getGuestJwtCallCount
        injectEndedSessionAccessResponse()

        do throws(ServerCallError) {
            try await sharedConfigRepository().refreshCommunityAccess()
            XCTFail("an ended session is no access")
        } catch {
            XCTAssertTrue(error.isSessionEnded)
        }

        // leave a replacement the time to happen
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, guestJwtCallCount)
        XCTAssertEqual(userDataStorage.userData?.id, "clientUserId")

        mockUserService.injectNextGetJwtFromClientResponse(newAccountJwtResponse())
        mockUserService.injectNextCanAccessCommunityResponse(.with { $0.canAccessCommunity = true })
        try await connectionRepository.connectUser(
            .init(userId: "clientUser", profile: .init(nickname: "ClientNickname", bio: nil, picture: nil)),
            tokenProvider: { "CLIENT_TOKEN" })

        XCTAssertEqual(userDataStorage.userData?.id, "newUserId")
        XCTAssertEqual(mockUserService.getJwtAuthenticatedFlags.last, false)
        XCTAssertEqual(mockUserService.getGuestJwtCallCount, guestJwtCallCount)
    }

    private func sharedConfigRepository() -> ConfigRepository {
        injector.getInjected(identifiedBy: Injected.configRepository)
    }

    /// The access read says the session is over.
    private func injectEndedSessionAccessResponse() {
        mockUserService.injectNextCanAccessCommunityResponse(.with {
            $0.canAccessCommunity = false
            $0.communityDisabledMessage = "Check back shortly"
            $0.sessionEnded = .init()
        })
    }

    /// The access read before the return still says the account is deleted.
    private func injectDeletedAccessResponse() {
        mockUserService.injectNextCanAccessCommunityResponse(.with {
            $0.canAccessCommunity = false
            $0.communityDisabledMessage = "Bye"
            $0.accountDeleted = .init()
        })
    }

    /// The account the server creates for the client user whose previous one was deleted.
    private func newAccountJwtResponse() -> Com_Octopuscommunity_GetJwtFromClientSignedTokenResponse {
        .with {
            $0.result = .success(.with {
                $0.jwt = "newJwt"
                $0.userID = "newUserId"
                $0.profile = .with {
                    $0.id = "newProfileId"
                    $0.nickname = "ClientNickname"
                    $0.hasSeenOnboarding_p = true
                    $0.hasAcceptedCgu_p = true
                    $0.hasConfirmedNickname_p = true
                    $0.hasConfirmedBio_p = true
                    $0.hasConfirmedPicture_p = true
                    $0.isGuest = false
                }
            })
        }
    }

    /// A repository whose member "clientUser" is connected with the account "clientUserId", which the access says
    /// has been deleted.
    private func makeRepositoryWithADeletedAccount() async throws -> SSOConnectionRepository {
        let connectionRepository = try await makeRepositoryConnectedAsGuest()
        mockUserService.injectNextGetJwtFromClientResponse(clientUserJwtResponse())
        mockUserService.injectNextCanAccessCommunityResponse(.with { $0.canAccessCommunity = true })
        mockUserService.injectNextUpdateProfileResponse(clientUserUpdatedProfileResponse())
        try await connectClientUser(connectionRepository)
        try await TaskUtils.wait(for: connectionRepository.connectionState.user?.profile.id == "clientProfileId",
                                 timeout: 5)

        let deleted = UserConfig(canAccessCommunity: false, accessDeniedMessage: "Bye",
                                 noAccessReason: .accountDeleted)
        try await userConfigDatabase.upsert(deleted)
        let configRepository: ConfigRepository = injector.getInjected(identifiedBy: Injected.configRepository)
        try await TaskUtils.wait(for: configRepository.userConfig == deleted, timeout: 2)
        return connectionRepository
    }

    /// A repository whose state is the guest "guestUserId".
    private func makeRepositoryConnectedAsGuest() async throws -> SSOConnectionRepository {
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "guestProfileId", userId: "guestUserId", nickname: "Guest", isGuest: true))
        let guestExpectation = XCTestExpectation(description: "Connected as guest")
        guestExpectation.assertForOverFulfill = false
        let connectionRepository = makeConnectionRepository { state in
            if case let .connected(user, nil) = state, user.profile.isGuest {
                guestExpectation.fulfill()
            }
        }
        await fulfillment(of: [guestExpectation], timeout: 5)
        return connectionRepository
    }

    private func storedProfile(userId: String) async -> StorableCurrentUserProfile? {
        // Not `publisher.values`, which only exists from iOS 15
        let read = XCTestExpectation(description: "Stored profile read")
        let stored = Locked<StorableCurrentUserProfile?>(nil)
        let cancellable = userProfileDatabase.profilePublisher(userId: userId).first().sink {
            stored.value = $0
            read.fulfill()
        }
        await fulfillment(of: [read], timeout: 5)
        cancellable.cancel()
        return stored.value
    }

    private func bannedAccessResponse(message: String, nickname: String? = nil)
    -> Com_Octopuscommunity_CanAccessCommunityResponse {
        .with {
            $0.canAccessCommunity = false
            $0.communityDisabledMessage = message
            $0.accountBanned = .with {
                if let nickname { $0.nickname = nickname }
                $0.policyName = "Job applications"
            }
        }
    }

    /// Connects the client user "clientUser": the exchange succeeds, the access read after it says the account is
    /// banned. Checks that `connectUser` reports the ban with `expectedMessage` (`message` when nil).
    private func connectBannedClientUser(_ connectionRepository: SSOConnectionRepository, message: String,
                                         nickname: String? = nil, expectedMessage: String? = nil,
                                         file: StaticString = #filePath, line: UInt = #line) async throws {
        mockUserService.injectNextGetJwtFromClientResponse(clientUserJwtResponse())
        mockUserService.injectNextCanAccessCommunityResponse(bannedAccessResponse(message: message, nickname: nickname))
        do {
            try await connectClientUser(connectionRepository)
            XCTFail("connectUser should have thrown the ban", file: file, line: line)
        } catch let error as ConnectionError {
            guard case let .detailedErrors(errors) = error else {
                XCTFail("Expected detailedErrors, got \(error)", file: file, line: line)
                return
            }
            XCTAssertEqual(errors.first?.reason, .userBanned, file: file, line: line)
            XCTAssertEqual(errors.first?.message, expectedMessage ?? message, file: file, line: line)
        }
    }

    private func closeCommunity() async {
        var config = Com_Octopuscommunity_ApiKeyConfig()
        config.closed = .with {
            $0.message = "Closed msg"
            $0.nextCheckAt = UInt64(Date().addingTimeInterval(3_600).timeIntervalSince1970 * 1000)
        }
        await injector.getInjected(identifiedBy: Injected.communityClosureRepository).handle(config: config)
    }

    private func reopenCommunity() async {
        await injector.getInjected(identifiedBy: Injected.communityClosureRepository)
            .handle(config: Com_Octopuscommunity_ApiKeyConfig())
    }

    private func memberProfile() -> StorableCurrentUserProfile {
        StorableCurrentUserProfile(id: "memberProfileId", userId: "memberUserId", nickname: "Member",
                                   originalNickname: nil,
                                   email: nil, bio: nil, pictureUrl: nil, tags: [],
                                   totalMessages: nil, accountCreationDate: nil,
                                   gamificationLevel: nil, gamificationScore: nil,
                                   hasSeenOnboarding: nil, hasAcceptedCgu: nil,
                                   hasConfirmedNickname: nil, hasConfirmedBio: nil,
                                   hasConfirmedPicture: nil,
                                   isGuest: false,
                                   notificationBadgeCount: 0,
                                   descPostFeedId: "", ascPostFeedId: "", blockedProfileIds: [])
    }

    /// Builds the repository and starts observing its state without letting the main queue run in between.
    ///
    /// `connectionState` starts at `.notConnected(nil)` and every change to it is delivered on the main
    /// queue, while `@Published` replays only the *current* value to a new subscriber. Building the
    /// repository and subscribing on the next line therefore races the queue: when it drains in that window
    /// — routine on a loaded CI machine — the subscriber's first value is already `.connected`, the initial
    /// state is lost and the ordered waits below fail. Parking a block on the main queue first puts the
    /// whole window behind it: the queue is serial and FIFO, so nothing the initialiser schedules there can
    /// be delivered until the subscription is in place.
    ///
    /// The observer is called one main queue turn after a state is published, not from the emission itself.
    /// `@Published` emits from `willSet`, before the property is written, and the repository writes its connected
    /// states from a sink on the main queue. Fulfilling an expectation straight from the emission therefore wakes
    /// the awaiting test while that sink is still mid-assignment, and what the test calls next reads the previous
    /// state: `logout()` then misses that the session is a guest one and drops the guest identity. Hopping
    /// once lands after that sink has returned, so the state handed to the observer is also the one the
    /// repository reads. The hop keeps the order: the initial value is queued while the main queue is held,
    /// ahead of every later change. States written off the main queue (the error path of `connect()`, logout)
    /// are not covered: the hop only narrows the gap for them.
    ///
    /// Safe whichever thread the test body runs on: the parked block is released before this returns, so a
    /// test that happens to run on the main queue simply finds the semaphore already signalled.
    private func makeConnectionRepository(observingState observe: @escaping (ConnectionState) -> Void)
    -> SSOConnectionRepository {
        let mainQueueHeld = DispatchSemaphore(value: 0)
        DispatchQueue.main.async { mainQueueHeld.wait() }
        defer { mainQueueHeld.signal() }

        let connectionRepository = SSOConnectionRepository(connectionMode: connectionMode,
                                                          injector: injector)
        connectionRepository.$connectionState
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: observe)
            .store(in: &storage)
        return connectionRepository
    }

    private func setupWithNonConnectedWithoutErrorState(previousProfileId: String? = nil) async throws {
        userDataStorage.store(clientUserData: nil)
        userDataStorage.store(userData: nil)
        if let previousProfileId {
            try await userProfileDatabase.delete(profileId: previousProfileId)
        }
    }

    private func setupWithExistingGuestProfile(_ profile: StorableCurrentUserProfile) async throws {
        guard profile.isGuest else {
            XCTFail("Profile must be a guest profile")
            return
        }
        userDataStorage.store(userData: .init(id: profile.userId, jwtToken: "fakeJwt"))
        XCTAssertNil(userDataStorage.clientUserData)
        try await userProfileDatabase.upsert(profile: profile)
        let guestInDbExpectation = XCTestExpectation(description: "Guest profile present in db")

        userProfileDatabase.profilePublisher(userId: profile.userId)
            .sink { profile in
                if let profile, profile.isGuest {
                    guestInDbExpectation.fulfill()
                }
            }.store(in: &storage)

        await fulfillment(of: [guestInDbExpectation], timeout: 5)
    }

    private func setupWithClientUserProfile(_ profile: StorableCurrentUserProfile, clientUserId: String)
    async throws {
        guard !profile.isGuest else {
            XCTFail("Profile must not be a guest profile")
            return
        }
        userDataStorage.store(userData: .init(id: profile.userId, jwtToken: "fakeJwt"))
        userDataStorage.store(clientUserData: .init(id: clientUserId))
        try await userProfileDatabase.upsert(profile: profile)
        let profileInDbExpectation = XCTestExpectation(description: "Profile present in db")

        userProfileDatabase.profilePublisher(userId: profile.userId)
            .sink { profile in
                if let profile, !profile.isGuest {
                    profileInDbExpectation.fulfill()
                }
            }.store(in: &storage)

        await fulfillment(of: [profileInDbExpectation], timeout: 5)
    }

    private func setCommunityAccess(_ canAccessCommunity: Bool) async throws {
        try await userConfigDatabase.upsert(canAccessCommunity: canAccessCommunity, message: nil)
        let configRepository: ConfigRepository = injector.getInjected(identifiedBy: Injected.configRepository)
        try? await TaskUtils.wait(for: configRepository.userConfig?.canAccessCommunity == canAccessCommunity,
                                  timeout: 2)
    }

    private func clientUserJwtResponse() -> Com_Octopuscommunity_GetJwtFromClientSignedTokenResponse {
        .with {
            $0.result = .success(.with {
                $0.jwt = "clientJwt"
                $0.userID = "clientUserId"
                $0.profile = .with {
                    $0.id = "clientProfileId"
                    $0.nickname = "OctopusNickname"
                    // not confirmed, so the nickname of the client user is sent in a profile update
                    $0.hasConfirmedNickname_p = false
                    $0.hasConfirmedBio_p = true
                    $0.hasConfirmedPicture_p = true
                    $0.isGuest = false
                }
            })
        }
    }

    /// Connects the client user "clientUser", with "ClientNickname" as nickname.
    private func connectClientUser(_ connectionRepository: SSOConnectionRepository) async throws {
        try await connectionRepository.connectUser(
            .init(userId: "clientUser", profile: .init(nickname: "ClientNickname", bio: nil, picture: nil)),
            tokenProvider: { "CLIENT_TOKEN" })
    }

    /// Stores the session the exchange gives the client user "clientUser", without the profile that would let the
    /// state show their account.
    private func storeClientSessionWithoutProfile() {
        userDataStorage.store(clientUserData: .init(id: "clientUser"))
        userDataStorage.store(userData: .init(id: "clientUserId", clientId: "clientUser", jwtToken: "clientJwt"))
    }

    /// Serves the guest "newGuestUserId", with the profile "newGuestProfileId", to the next guest connection.
    private func injectNewGuestResponse() {
        mockUserService.injectNextGetGuestJwtResponse(.with {
            $0.result = .success(.with {
                $0.jwt = "newGuestJwt"
                $0.userID = "newGuestUserId"
                $0.profile = .with {
                    $0.id = "newGuestProfileId"
                    $0.nickname = "Guest"
                    $0.isGuest = true
                }
            })
        })
    }

    /// The exchange of a user whose profile is from before frictionless profiles: without confirmation flags, it has
    /// to be migrated.
    private func legacyClientUserJwtResponse() -> Com_Octopuscommunity_GetJwtFromClientSignedTokenResponse {
        .with {
            $0.result = .success(.with {
                $0.jwt = "clientJwt"
                $0.userID = "clientUserId"
                $0.profile = .with {
                    $0.id = "clientProfileId"
                    $0.nickname = "OctopusNickname"
                    $0.isGuest = false
                }
            })
        }
    }

    private func clientUserUpdatedProfileResponse() -> Com_Octopuscommunity_UpdateProfileResponse {
        .with {
            $0.result = .success(.with {
                $0.profile = .with {
                    $0.id = "clientProfileId"
                    $0.nickname = "ClientNickname"
                    $0.hasConfirmedNickname_p = false
                    $0.hasConfirmedBio_p = true
                    $0.hasConfirmedPicture_p = true
                    $0.isGuest = false
                }
            })
        }
    }

    /// Connects the client user "clientUser": the exchange of their token succeeds, the update of their profile
    /// is refused because they cannot access the community. A guest is ready to be served, so that falling back
    /// to one shows in `getGuestJwtCallCount` instead of failing on a missing response.
    /// - Parameter exchange: the answer to the exchange of the token, `clientUserJwtResponse()` when nil.
    private func connectClientUserRefusedCommunityAccess(
        _ connectionRepository: SSOConnectionRepository,
        exchange: Com_Octopuscommunity_GetJwtFromClientSignedTokenResponse? = nil
    ) async throws {
        mockUserService.injectNextGetJwtFromClientResponse(exchange ?? clientUserJwtResponse())
        mockUserService.injectNextUpdateProfileError(.permissionDenied(reason: nil))
        mockUserService.injectNextGetGuestJwtResponse(.with {
            $0.result = .success(.with {
                $0.jwt = "newGuestJwt"
                $0.userID = "newGuestUserId"
                $0.profile = .with {
                    $0.id = "newGuestProfileId"
                    $0.nickname = "Guest"
                    $0.isGuest = true
                }
            })
        })

        do {
            try await connectionRepository.connectUser(
                .init(userId: "clientUser", profile: .init(nickname: "ClientNickname", bio: nil, picture: nil)),
                tokenProvider: { "CLIENT_TOKEN" })
            XCTFail("connectUser should have thrown an error")
        } catch let error as ConnectionError {
            guard case .communityAccessDenied = error else {
                XCTFail("Expected communityAccessDenied, got \(error)")
                return
            }
        }
    }

    /// Whether `error` is the one `connectUser` throws when it gives up on an unreadable session.
    private func isUnreadableSessionError(_ error: Error) -> Bool {
        guard case let ConnectionError.unknown(underlying) = error,
              case InternalError.explainedError(_)? = underlying else { return false }
        return true
    }

    /// Writes a session straight into the secured storage, as a previous launch would have left it.
    private func storeSession(in securedStorage: MockSecuredStorage, userId: String, clientUserId: String) throws {
        try securedStorage.set(userId, key: "user_id")
        try securedStorage.set("jwt", key: "user_jwtToken")
        try securedStorage.set(clientUserId, key: "user_clientId")
        try securedStorage.set(clientUserId, key: "client_user_id")
    }
}
