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
    private var userDataStorage: UserDataStorage!
    private var userProfileDatabase: CurrentUserProfileDatabase!
    private var storage = [AnyCancellable]()

    override func setUp() {
        let connectionMode = ConnectionMode.sso(.init(appManagedFields: [], loginRequired: { }, modifyUser: { _ in }))
        injector = Injector()
        injector.register { _ in try! ModelCoreDataStack(inRam: true) }
        injector.register { CurrentUserProfileDatabase(injector: $0) }
        injector.register { ProfileRepositoryDefault(appManagedFields: [], injector: $0) }
        injector.registerMocks(.remoteClient, .securedStorage, .networkMonitor,
                               .userProfileFetchMonitor, .blockedUserIdsProvider)
        injector.register { UserDataStorage(injector: $0) }
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
        injector.register { ClientUserProvider(connectionMode: connectionMode, injector: $0) }
        injector.register { ClientUserProfileDatabase(injector: $0) }

        mockUserService = (injector.getInjected(identifiedBy: Injected.remoteClient)
            .userService as! MockUserService)

        userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        userProfileDatabase = injector.getInjected(identifiedBy: Injected.currentUserProfileDatabase)

    }

    func testDefaultStateIsNotConnectedWhenNothingIsPresent() async throws {
        // Precondition: no client user data, no user id, no profile in db
        try await setupWithNonConnectedWithoutErrorState()

        let connectionRepository = SSOConnectionRepository(connectionMode: .octopus(deepLink: nil), injector: injector)
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

        let connectionRepository = SSOConnectionRepository(connectionMode: .octopus(deepLink: nil), injector: injector)
        connectionRepository.$connectionState.sink { state in
            switch state {
            case let .connected(user, nil) where user.profile.isGuest:
                guestExpectation.fulfill()
            default:
                break
            }
        }.store(in: &storage)

        await fulfillment(of: [guestExpectation], timeout: 0.5)
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

        let connectionRepository = SSOConnectionRepository(connectionMode: .octopus(deepLink: nil), injector: injector)
        connectionRepository.$connectionState.sink { state in
            switch state {
            case .notConnected(nil):
                notConnectedExpectation.fulfill()
            case let .connected(user, nil) where user.profile.isGuest:
                guestExpectation.fulfill()
            default:
                XCTFail("State is \(connectionRepository.connectionState).")
            }
        }.store(in: &storage)

        await fulfillment(of: [notConnectedExpectation, guestExpectation], timeout: 0.5, enforceOrder: true)
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

        let connectionRepository = SSOConnectionRepository(connectionMode: .octopus(deepLink: nil), injector: injector)
        connectionRepository.$connectionState.sink { state in
            switch state {
            case .notConnected(nil):
                notConnectedExpectation.fulfill()
            case .notConnected:
                notConnectedWithErrorExpectation.fulfill()
            default:
                XCTFail("State is \(connectionRepository.connectionState).")
            }
        }.store(in: &storage)

        await fulfillment(of: [notConnectedExpectation, notConnectedWithErrorExpectation], timeout: 0.5,
                          enforceOrder: true)
    }

    func testFromGuestToNonGuestAfterClientUserConnected() async throws {
        let notConnectedExpectation = XCTestExpectation(description: "State is not connected")
        let guestExpectation = XCTestExpectation(description: "Guest profile present")
        let authProfileExpectation = XCTestExpectation(description: "Authenticated profile present")

        // Precondition: user id and guest profile in db and no client user data
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "profileId", userId: "userId", nickname: "Guest", isGuest: true))

        let connectionRepository = SSOConnectionRepository(connectionMode: .octopus(deepLink: nil), injector: injector)
        connectionRepository.$connectionState.sink { state in
            switch state {
            case .notConnected(nil):
                notConnectedExpectation.fulfill()
            case let .connected(user, nil) where user.profile.isGuest:
                guestExpectation.fulfill()
            case let .connected(user, nil) where !user.profile.isGuest:
                authProfileExpectation.fulfill()
            default:
                XCTFail("State is \(connectionRepository.connectionState).")
            }
        }.store(in: &storage)

        await fulfillment(of: [notConnectedExpectation, guestExpectation], timeout: 0.5,
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

        await fulfillment(of: [authProfileExpectation], timeout: 0.5)
    }

    func testFromGuestToNonGuestAfterClientUserConnectedWithError() async throws {
        let notConnectedExpectation = XCTestExpectation(description: "State is not connected")
        let guestExpectation = XCTestExpectation(description: "Guest profile present")
        let guestWithErrorExpectation = XCTestExpectation(description: "Guest profile present with auth error")

        // Precondition: user id and guest profile in db and no client user data
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "profileId", userId: "userId", nickname: "Guest", isGuest: true))

        let connectionRepository = SSOConnectionRepository(connectionMode: .octopus(deepLink: nil), injector: injector)
        connectionRepository.$connectionState.sink { state in
            switch state {
            case .notConnected(nil):
                notConnectedExpectation.fulfill()
            case let .connected(user, nil) where user.profile.isGuest:
                guestExpectation.fulfill()
            case let .connected(user, _) where user.profile.isGuest:
                guestWithErrorExpectation.fulfill()
            default:
                XCTFail("State is \(connectionRepository.connectionState).")
            }
        }.store(in: &storage)

        await fulfillment(of: [notConnectedExpectation, guestExpectation], timeout: 0.5,
                          enforceOrder: true)

        // The getFrictionlessJwt service will be called right after the connectUser
        // Mock backend response.
        mockUserService.injectNextGetJwtFromClientResponse(.with {
            $0.result = .fail(.with {
                $0.errors = []
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

        await fulfillment(of: [guestWithErrorExpectation], timeout: 0.5)
    }

    func testFromClientUserConnectedToAnotherClientConnected() async throws {
        let notConnectedExpectation = XCTestExpectation(description: "State is not connected")
        let connected1Expectation = XCTestExpectation(description: "Client user connected and profile present")
        let connected2Expectation = XCTestExpectation(description: "Another client user connected and profile present")

        // Precondition: user id and guest profile in db and no client user data
        try await setupWithClientUserProfile(StorableCurrentUserProfile.create(
            id: "profileId", userId: "firstUserId", nickname: "ClientUser1", isGuest: false),
        clientUserId: "clientUser1")

        let connectionRepository = SSOConnectionRepository(connectionMode: .octopus(deepLink: nil), injector: injector)
        connectionRepository.$connectionState.sink { state in
            switch state {
            case .notConnected(nil):
                notConnectedExpectation.fulfill()
            case let .connected(user, nil) where user.profile.userId == "firstUserId":
                connected1Expectation.fulfill()
            case let .connected(user, nil) where user.profile.userId == "newUserId":
                connected2Expectation.fulfill()
            default:
                XCTFail("State is \(connectionRepository.connectionState).")
            }
        }.store(in: &storage)

        await fulfillment(of: [notConnectedExpectation, connected1Expectation], timeout: 0.5,
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

        await fulfillment(of: [connected2Expectation], timeout: 0.5)
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
            .replaceError(with: nil)
            .sink { profile in
                if let profile, profile.isGuest {
                    guestInDbExpectation.fulfill()
                }
            }.store(in: &storage)

        await fulfillment(of: [guestInDbExpectation], timeout: 0.5)
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
            .replaceError(with: nil)
            .sink { profile in
                if let profile, !profile.isGuest {
                    profileInDbExpectation.fulfill()
                }
            }.store(in: &storage)

        await fulfillment(of: [profileInDbExpectation], timeout: 0.5)
    }
}
