////
////  Copyright © 2024 Octopus Community. All rights reserved.
////
//
//import Foundation
//import XCTest
//import Combine
//import OctopusDependencyInjection
//import OctopusRemoteClient
//import OctopusGrpcModels
//import SwiftProtobuf
//@testable import OctopusCore
//
//class MagicLinkConnectionTests: XCTestCase {
//    /// Object that is tested
//    private var connectionRepository: ConnectionRepository!
//
//    private var mockMagicLinkService: MockMagicLinkService!
//    private var mockMagicLinkMonitor: MockMagicLinkMonitor!
//    private var mockUserService: MockUserService!
//    private var mockUserProfileFetchMonitor: MockUserProfileFetchMonitor!
//    private var userDataStorage: UserDataStorage!
//    private var userProfileDatabase: CurrentUserProfileDatabase!
//    private var storage = [AnyCancellable]()
//
//    override func setUp() {
//        let injector = Injector()
//        injector.register { _ in try! ModelCoreDataStack(inRam: true) }
//        injector.register { CurrentUserProfileDatabase(injector: $0) }
//        injector.register { PublicProfileDatabase(injector: $0) }
//        injector.register { ProfileRepositoryDefault(appManagedFields: [], injector: $0) }
//        injector.registerMocks(.remoteClient, .securedStorage, .networkMonitor, .magicLinkMonitor,
//                               .userProfileFetchMonitor, .blockedUserIdsProvider)
//        injector.register { UserDataStorage(injector: $0) }
//        injector.register { AuthenticatedCallProviderDefault(injector: $0) }
//        injector.register { _ in Validators(appManagedFields: []) }
//        injector.register { PostFeedsStore(injector: $0) }
//        injector.register { CommentFeedsStore(injector: $0) }
//        injector.register { ReplyFeedsStore(injector: $0) }
//        injector.register { RepliesDatabase(injector: $0) }
//        injector.register { CommentsDatabase(injector: $0) }
//        injector.register { PostsDatabase(injector: $0) }
//        injector.register { FeedItemInfosDatabase(injector: $0) }
//        injector.register { ClientUserProvider(connectionMode: .octopus(deepLink: nil), injector: $0) }
//
//
//        connectionRepository = MagicLinkConnectionRepository(connectionMode: .octopus(deepLink: nil), injector: injector)
//        mockMagicLinkService = (injector.getInjected(identifiedBy: Injected.remoteClient)
//            .magicLinkService as! MockMagicLinkService)
//        mockUserService = (injector.getInjected(identifiedBy: Injected.remoteClient)
//            .userService as! MockUserService)
//        mockMagicLinkMonitor = (injector.getInjected(identifiedBy: Injected.magicLinkMonitor) as! MockMagicLinkMonitor)
//        mockUserProfileFetchMonitor = (injector.getInjected(
//            identifiedBy: Injected.userProfileFetchMonitor) as! MockUserProfileFetchMonitor)
//
//        userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
//        userProfileDatabase = injector.getInjected(identifiedBy: Injected.currentUserProfileDatabase)
//    }
//
//    func testConnectedAfterMagicLinkConfirmed() async throws {
//        let magicLinkSentExpectation = XCTestExpectation(description: "Magic link is sent")
//        let loggedInExpectation = XCTestExpectation(description: "User is logged in")
//
//        var magicLinkRequest: MagicLinkRequest?
//        var user: User?
//
//        connectionRepository.connectionStatePublisher.sink { connectionState in
//            switch connectionState {
//            case .notConnected: break
//            case let .magicLinkSent(request):
//                magicLinkRequest = request
//                magicLinkSentExpectation.fulfill()
//            case let .connected(connectedUser):
//                user = connectedUser
//                loggedInExpectation.fulfill()
//            default: break
//            }
//        }.store(in: &storage)
//
//        guard case .notConnected = connectionRepository.connectionState else {
//            XCTFail("Connection state is expected to be '.notConnected'")
//            return
//        }
//
//        mockMagicLinkService.injectNextGenerateLinkResponse(.with { $0.magicLinkID = "123" })
//
//        try await connectionRepository.sendMagicLink(to: "t@t.c")
//        await fulfillment(of: [magicLinkSentExpectation], timeout: 0.5)
//        XCTAssertNotNil(magicLinkRequest)
//        XCTAssert(magicLinkRequest?.email == "t@t.c")
//        XCTAssert(magicLinkRequest?.error == nil)
//
//        mockMagicLinkService.injectNextGetJwtResponse(.with {
//            $0.result = .success(.with {
//                $0.jwt = "abc"
//                $0.userID = "userId"
//                $0.profile = .with {
//                    $0.id = "profileId"
//                    $0.nickname = "nickname"
//                }
//            })
//        })
//        let result = try await connectionRepository.checkMagicLinkConfirmed()
//        XCTAssertTrue(result)
//        await fulfillment(of: [loggedInExpectation], timeout: 0.5)
//        XCTAssertNotNil(user)
//        XCTAssert(user?.profile.id == "profileId")
//        XCTAssert(user?.profile.userId == "userId")
//        XCTAssert(user?.jwtToken == "abc")
//    }
//
//    func testMagicLinkConfirmationError() async throws {
//        let magicLinkSentExpectation = XCTestExpectation(description: "Magic link is sent")
//        let errorExpectation = XCTestExpectation(description: "An error has been catched")
//
//        var magicLinkRequest: MagicLinkRequest?
//
//        connectionRepository.connectionStatePublisher.sink { connectionState in
//            switch connectionState {
//            case let .magicLinkSent(request):
//                magicLinkRequest = request
//                magicLinkSentExpectation.fulfill()
//            default: break
//            }
//        }.store(in: &storage)
//
//        guard case .notConnected = connectionRepository.connectionState else {
//            XCTFail("Connection state is expected to be '.notConnected'")
//            return
//        }
//
//        mockMagicLinkService.injectNextGenerateLinkResponse(.with { $0.magicLinkID = "123" })
//
//        try await connectionRepository.sendMagicLink(to: "t@t.c")
//        await fulfillment(of: [magicLinkSentExpectation], timeout: 0.5)
//        XCTAssertNotNil(magicLinkRequest)
//        XCTAssert(magicLinkRequest?.email == "t@t.c")
//        XCTAssert(magicLinkRequest?.error == nil)
//
//        mockMagicLinkService.injectNextGetJwtResponse(.with {
//            $0.result = .error(.with {
//                $0.errorCode = .linkNotFound
//                $0.message = ""
//            })
//        })
//        do {
//            _ = try await connectionRepository.checkMagicLinkConfirmed()
//        } catch {
//            if case .needNewMagicLink = error {
//                errorExpectation.fulfill()
//            }
//        }
//        // let the error be catched by the user repository
//        try await delay()
//        await fulfillment(of: [errorExpectation], timeout: 0.5)
//        XCTAssertNotNil(magicLinkRequest)
//        XCTAssert(magicLinkRequest?.email == "t@t.c")
//        guard case .needNewMagicLink = magicLinkRequest?.error else {
//            XCTFail("MagicLinkRequest error is expected to be '.noMagicLink'")
//            return
//        }
//    }
//
//    func testCancelMagicLink() async throws {
//        let magicLinkSentExpectation = XCTestExpectation(description: "Magic link is sent")
//        let notConnectedExpectation = XCTestExpectation(description: "Not connected")
//
//        connectionRepository.connectionStatePublisher.sink { connectionState in
//            switch connectionState {
//            case .magicLinkSent:
//                magicLinkSentExpectation.fulfill()
//            default: break
//            }
//        }.store(in: &storage)
//
//        guard case .notConnected = connectionRepository.connectionState else {
//            XCTFail("Connection state is expected to be '.notConnected'")
//            return
//        }
//
//        mockMagicLinkService.injectNextGenerateLinkResponse(.with { $0.magicLinkID = "123" })
//
//        try await connectionRepository.sendMagicLink(to: "t@t.c")
//        await fulfillment(of: [magicLinkSentExpectation], timeout: 0.5)
//
//        connectionRepository.connectionStatePublisher.sink { connectionState in
//            switch connectionState {
//            case .notConnected:
//                notConnectedExpectation.fulfill()
//            default: break
//            }
//        }.store(in: &storage)
//        connectionRepository.cancelMagicLink()
//        await fulfillment(of: [notConnectedExpectation], timeout: 0.5)
//    }
//
//    @MainActor // TODO: remove that later, when Github tests are not failing
//    func testUsesResponsesFromMonitor() async throws {
//        let errorExpectation = XCTestExpectation(description: "An error has been catched")
//        let loggedInExpectation = XCTestExpectation(description: "User is logged in")
//
//        var user: User?
//
//        connectionRepository.connectionStatePublisher.sink { connectionState in
//            switch connectionState {
//            case let .magicLinkSent(request):
//                if request.error != nil {
//                    errorExpectation.fulfill()
//                }
//            case let .connected(connectedUser):
//                user = connectedUser
//                loggedInExpectation.fulfill()
//            case .profileCreationRequired:
//                XCTFail("Profile creation should not be required")
//            default: break
//            }
//        }.store(in: &storage)
//
//        mockMagicLinkService.injectNextGenerateLinkResponse(.with { $0.magicLinkID = "123" })
//
//        try await connectionRepository.sendMagicLink(to: "t@t.c")
//        try await delay()
//
//        mockMagicLinkMonitor.magicLinkAuthenticationResponse = .with {
//            $0.result = .error(.with {
//                $0.errorCode = .linkNotFound
//                $0.message = ""
//            })
//        }
//        await fulfillment(of: [errorExpectation], timeout: 0.5)
//
//        mockMagicLinkMonitor.magicLinkAuthenticationResponse = .with {
//            $0.result = .success(.with {
//                $0.jwt = "abc"
//                $0.userID = "userId"
//                $0.profile = .with {
//                    $0.id = "profileId"
//                    $0.nickname = "nickname"
//                }
//            })
//        }
//        await fulfillment(of: [loggedInExpectation], timeout: 0.5)
//        XCTAssertNotNil(user)
//        XCTAssert(user?.profile.id == "profileId")
//        XCTAssert(user?.profile.userId == "userId")
//        XCTAssert(user?.jwtToken == "abc")
//    }
//
//    func testProfileCreationRequiredAfterMagicLinkConfirmed() async throws {
//        let profileCreationRequiredExpectation = XCTestExpectation(description: "Profile creation is required")
//
//        connectionRepository.connectionStatePublisher.sink { connectionState in
//            switch connectionState {
//            case .profileCreationRequired:
//                profileCreationRequiredExpectation.fulfill()
//            case .connected:
//                XCTFail("Connected state is not expected")
//            default: break
//            }
//        }.store(in: &storage)
//
//
//        // precondition: magic link is sent and is about to be confirmed
//        mockMagicLinkService.injectNextGenerateLinkResponse(.with { $0.magicLinkID = "123" })
//        try await connectionRepository.sendMagicLink(to: "t@t.c")
//        try await delay()
//        mockMagicLinkMonitor.magicLinkAuthenticationResponse = .with {
//            $0.result = .success(.with {
//                $0.jwt = "abc"
//                $0.userID = "userId"
//            })
//        }
//        // after precondition, state is fetching profile
//
//        await fulfillment(of: [profileCreationRequiredExpectation], timeout: 0.5)
//    }
//
//    func testDeleteProfile() async throws {
//        // preconditions: user is logged in
//        userDataStorage.store(userData: .init(id: "user_id", jwtToken: "fake_jwt"))
//        try await userProfileDatabase.upsert(
//            profile: .init(id: "profile_id", userId: "user_id",
//                           nickname: "Nickname", email: nil, bio: nil, pictureUrl: nil,
//                           hasSeenOnboarding: nil, hasAcceptedCgu: nil,
//                           hasConfirmedNickname: nil, isGuest: true,
//                           notificationBadgeCount: 0,
//                           descPostFeedId: "", ascPostFeedId: "", blockedProfileIds: []))
//
//        // precondition expectation
//        let userIsLoggedInExpectation = XCTestExpectation(description: "User is logged in")
//        connectionRepository.connectionStatePublisher.sink { connectionState in
//            switch connectionState {
//            case .connected:
//                userIsLoggedInExpectation.fulfill()
//            default: break
//            }
//        }.store(in: &storage)
//        await fulfillment(of: [userIsLoggedInExpectation], timeout: 0.5)
//
//        // Test success expectation
//        let userIsLoggedOutExpectation = XCTestExpectation(description: "User is logged out")
//        connectionRepository.connectionStatePublisher.sink { connectionState in
//            switch connectionState {
//            case .notConnected:
//                userIsLoggedOutExpectation.fulfill()
//            default: break
//            }
//        }.store(in: &storage)
//
//        // check that calling deleteProfile call the backend and, if call succeed, logout the user
//        mockUserService.injectNextDeleteAccountResponse(.init())
//        try await connectionRepository.deleteAccount(reason: .communityQuality)
//
//        await fulfillment(of: [userIsLoggedOutExpectation], timeout: 0.5)
//    }
//}
