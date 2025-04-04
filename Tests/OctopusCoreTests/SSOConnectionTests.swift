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
    /// Object that is tested
    private var connectionRepository: ConnectionRepository!

    private var mockUserService: MockUserService!
    private var mockUserProfileFetchMonitor: MockUserProfileFetchMonitor!
    private var userDataStorage: UserDataStorage!
    private var userProfileDatabase: CurrentUserProfileDatabase!
    private var storage = [AnyCancellable]()

    override func setUp() {
        let connectionMode = ConnectionMode.sso(.init(appManagedFields: [], loginRequired: { }, modifyUser: { _ in }))
        let injector = Injector()
        injector.register { _ in try! CoreDataStack(inRam: true) }
        injector.register { CurrentUserProfileDatabase(injector: $0) }
        injector.register { ClientUserProfileDatabase(injector: $0) }
        injector.register { PublicProfileDatabase(injector: $0) }
        injector.register { ProfileRepository(appManagedFields: [], injector: $0) }
        injector.registerMocks(.remoteClient, .securedStorage, .networkMonitor,
                               .userProfileFetchMonitor, .blockedUserIdsProvider)
        injector.register { UserDataStorage(injector: $0) }
        injector.register { AuthenticatedCallProviderDefault(injector: $0) }
        injector.register { _ in Validators(appManagedFields: []) }
        injector.register { PostFeedsStore(injector: $0) }
        injector.register { CommentFeedsStore(injector: $0) }
        injector.register { CommentsDatabase(injector: $0) }
        injector.register { PostsDatabase(injector: $0) }
        injector.register { FeedItemInfosDatabase(injector: $0) }
        injector.register { ClientUserProvider(connectionMode: connectionMode, injector: $0) }


        connectionRepository = SSOConnectionRepository(connectionMode: connectionMode, injector: injector)
        mockUserService = (injector.getInjected(identifiedBy: Injected.remoteClient)
            .userService as! MockUserService)
        mockUserProfileFetchMonitor = (injector.getInjected(
            identifiedBy: Injected.userProfileFetchMonitor) as! MockUserProfileFetchMonitor)

        userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        userProfileDatabase = injector.getInjected(identifiedBy: Injected.currentUserProfileDatabase)
    }

    func testConnectedAfterClientTokenExchanged() async throws {
        let clientConnectedExpectation = XCTestExpectation(description: "Client is connected")
        let loggedInExpectation = XCTestExpectation(description: "User is logged in")

        // Simulate a long lasting call from the client to get the client user token
        var simulateGetClientTokenFinished = false
        var clientUserTokenAsked = false
        var user: User?

        connectionRepository.connectionStatePublisher.sink { connectionState in
            switch connectionState {
            case .notConnected: break
            case let .clientConnected(_, error):
                guard error == nil else { return }
                clientConnectedExpectation.fulfill()
            case let .connected(connectedUser):
                user = connectedUser
                loggedInExpectation.fulfill()
            default: break
            }
        }.store(in: &storage)

        guard case .notConnected = connectionRepository.connectionState else {
            XCTFail("Connection state is expected to be '.notConnected'")
            return
        }

        try await connectionRepository.connectUser(
            .init(userId: "clientUserId", profile: .empty),
            tokenProvider: {
                clientUserTokenAsked = true
                // If a fetch is currently happening, wait for its end
                while !simulateGetClientTokenFinished {
                    try? await Task.sleep(nanoseconds: 10)
                }
                return "fake_client_token"
            })

        await fulfillment(of: [clientConnectedExpectation], timeout: 0.5)
        XCTAssert(clientUserTokenAsked)

        // simulate that the backend has sent the token
        mockUserService.injectNextGetJwtFromClientResponse(.with {
            $0.result = .success(.with {
                $0.jwt = "fake_jwt"
                $0.userID = "userId"
                $0.profile = .with {
                    $0.id = "profileId"
                    $0.nickname = "nickname"
                }
            })
        })

        // Simulate the fact that the client received the client user token. The monitor should automatically fetch
        // the token
        simulateGetClientTokenFinished = true

        await fulfillment(of: [loggedInExpectation], timeout: 0.5)
        XCTAssertNotNil(user)
        XCTAssert(user?.profile.id == "profileId")
        XCTAssert(user?.profile.userId == "userId")
        XCTAssert(user?.jwtToken == "fake_jwt")
    }

    func testTokenExchangeError() async throws {
        let errorExpectation = XCTestExpectation(description: "An error has been catched")

        connectionRepository.connectionStatePublisher.sink { connectionState in
            switch connectionState {
            case .notConnected: break
            case let .clientConnected(_, error):
                if error != nil {
                    errorExpectation.fulfill()
                }
            default: break
            }
        }.store(in: &storage)

        guard case .notConnected = connectionRepository.connectionState else {
            XCTFail("Connection state is expected to be '.notConnected'")
            return
        }

        // simulate that the monitor has fetched the token
        mockUserService.injectNextGetJwtFromClientResponse(.with {
            $0.result = .fail(.with {
                $0.errors = [
                    .with {
                        $0.message = "Invalid client token"
                        $0.errorCode = .userBanned
                    }
                ]
            })
        })

        try await connectionRepository.connectUser(
            .init(userId: "clientUserId", profile: .empty),
            tokenProvider: {
                return "invalid_client_token"
            })

        await fulfillment(of: [errorExpectation], timeout: 0.5)
    }
}
