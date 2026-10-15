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

    override func setUp() {
        let sessionReadTrigger = PassthroughSubject<Void, Never>()
        self.sessionReadTrigger = sessionReadTrigger
        injector = Injector()
        injector.register { _ in try! ModelCoreDataStack(inRam: true) }
        injector.register { _ in try! ConfigCoreDataStack(inRam: true) }
        injector.register { CurrentUserProfileDatabase(injector: $0) }
        injector.register { ProfileRepositoryDefault(appManagedFields: [], injector: $0) }
        injector.registerMocks(.remoteClient, .securedStorage, .networkMonitor,
                               .userProfileFetchMonitor, .blockedUserIdsProvider, .appStateMonitor)
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
        injector.register { ClientUserProfileMerger(appManagedFields: [], injector: $0) }
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
