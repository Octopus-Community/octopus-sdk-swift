//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import XCTest
import Combine
import OctopusDependencyInjection
@testable import OctopusRemoteClient
@testable import OctopusCore

class AuthenticatedCallProviderTests: XCTestCase {
    /// Object that is tested
    private var authenticatedCallProvider: AuthenticatedCallProvider!

    private var injector: Injector! // need to store it because AuthenticatedCallProviderDefault has a weak var of it
    private var userDataStorage: UserDataStorage!
    private var connectionRepository: MockConnectionRepository!

    override func setUp() {
        injector = Injector()
        injector.register { MockConnectionRepository(injector: $0) }
        injector.register { _ in try! ModelCoreDataStack(inRam: true) }
        injector.registerMocks(.securedStorage, .remoteClient, .networkMonitor, .blockedUserIdsProvider)
        injector.register { UserDataStorage(injector: $0) }
        injector.register { PostFeedsStore(injector: $0) }
        injector.register { CommentFeedsStore(injector: $0) }
        injector.register { ReplyFeedsStore(injector: $0) }
        injector.register { RepliesDatabase(injector: $0) }
        injector.register { CommentsDatabase(injector: $0) }
        injector.register { PostsDatabase(injector: $0) }
        injector.register { FeedItemInfosDatabase(injector: $0) }
        injector.register { AuthenticatedCallProviderDefault(injector: $0) }

        authenticatedCallProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)
        connectionRepository = (injector.getInjected(identifiedBy: Injected.connectionRepository) as! MockConnectionRepository)
    }

    func testAuthenticatedMethodWhenConnected() async throws {
        connectionRepository.mock(connected: true)

        // check that it should not throw an error
        let method = try authenticatedCallProvider.authenticatedMethod()

        switch method {
        case let .authenticated(_, authFailure):
            // check that if authFailure block is called, user is logged out
            authFailure()
            try await assertWithTimeout {
                if case .notConnected = self.connectionRepository.connectionState { return true }
                return false
            }
        case .notAuthenticated:
            XCTFail("authenticatedMethod should not return .notAuthenticated")
        }
    }

    func testAuthenticatedMethodWhenNotConnected() async throws {
        connectionRepository.mock(connected: false)

        // check that it should not throw an error
        XCTAssertThrowsError(try authenticatedCallProvider.authenticatedMethod()) {
            switch $0 {
            case AuthenticatedActionError.userNotAuthenticated:
                break
            default:
                XCTFail(".userNotAuthenticated error expected")
            }
        }
    }

    func testAuthenticatedMethodIfPossibleWhenConnected() async throws {
        connectionRepository.mock(connected: true)

        let method = authenticatedCallProvider.authenticatedIfPossibleMethod()

        switch method {
        case let .authenticated(_, authFailure):
            // check that if authFailure block is called, user is logged out
            authFailure()
            try await assertWithTimeout {
                if case .notConnected = self.connectionRepository.connectionState { return true }
                return false
            }
        case .notAuthenticated:
            XCTFail("authenticatedMethod should not return .notAuthenticated")
        }
    }

    func testAuthenticatedMethodIfPossibleWhenNotConnected() async throws {
        connectionRepository.mock(connected: false)

        let method = authenticatedCallProvider.authenticatedIfPossibleMethod()

        switch method {
        case .authenticated:
            XCTFail(".notAuthenticated expected")
        case .notAuthenticated:
            break // expected result
        }
    }

    func testReadIsSentAgainWithTheNewSessionWhenTheSessionChangedDuringTheCall() async throws {
        connectionRepository.mock(connected: false)
        let userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        var sentTokens = [String?]()

        let result = try await authenticatedCallProvider.withAuthenticatedIfPossibleMethod { method in
            sentTokens.append(method.token)
            if sentTokens.count == 1 {
                // The member signs in while the first call is in flight.
                userDataStorage.store(userData: .init(id: "member_id", jwtToken: "member_token"))
                throw Self.sessionChangedError
            }
            return "response"
        }

        XCTAssertEqual(result, "response")
        XCTAssertEqual(sentTokens, [nil, "member_token"])
    }

    func testReadIsNotSentAgainOnAnotherError() async throws {
        connectionRepository.mock(connected: true)
        var attempts = 0

        do {
            _ = try await authenticatedCallProvider.withAuthenticatedIfPossibleMethod { _ -> String in
                attempts += 1
                throw RemoteClientError.timeout
            }
            XCTFail("The error should be thrown")
        } catch {
            guard case RemoteClientError.timeout = error else {
                XCTFail("Unexpected error \(error)")
                return
            }
        }
        XCTAssertEqual(attempts, 1)
    }

    func testReadGivesUpWhenTheSessionKeepsChanging() async throws {
        connectionRepository.mock(connected: true)
        var attempts = 0

        do {
            _ = try await authenticatedCallProvider.withAuthenticatedIfPossibleMethod { _ -> String in
                attempts += 1
                throw Self.sessionChangedError
            }
            XCTFail("The error should be thrown")
        } catch {
            XCTAssertTrue(error.isSessionChangedDuringCall)
        }
        // A member switching community goes through three changes in a row: member, none, guest, member.
        XCTAssertEqual(attempts, 4)
    }

    func testCancelledReadIsNotSentAgain() async throws {
        connectionRepository.mock(connected: true)
        var attempts = 0

        do {
            _ = try await authenticatedCallProvider.withAuthenticatedIfPossibleMethod { _ -> String in
                attempts += 1
                // The screen that wanted the read goes away while it is in flight.
                withUnsafeCurrentTask { $0?.cancel() }
                throw Self.sessionChangedError
            }
            XCTFail("The error should be thrown")
        } catch {
            XCTAssertTrue(error.isSessionChangedDuringCall)
        }
        XCTAssertEqual(attempts, 1)
    }

    func testReplayIsToldApartFromTheFirstAttempt() async throws {
        connectionRepository.mock(connected: true)
        var replayFlags = [Bool]()

        _ = try await authenticatedCallProvider.withAuthenticatedIfPossibleMethod { _, isReplay -> String in
            replayFlags.append(isReplay)
            // The first attempt's response is refused: the server still handled it, a view included.
            if replayFlags.count == 1 { throw Self.sessionChangedError }
            return "response"
        }

        XCTAssertEqual(replayFlags, [false, true])
    }

    /// The error a call ends with when its response comes back after the session changed.
    private static let sessionChangedError = RemoteClientError.unknown(RefreshingTokenError.userIdNotMatching)
}

private extension AuthenticationMethod {
    var token: String? {
        switch self {
        case let .authenticated(token, _): token
        case .notAuthenticated: nil
        }
    }
}

private final class MockConnectionRepository: ConnectionRepository, InjectableObject, @unchecked Sendable {
    static let injectedIdentifier = Injected.connectionRepository

    var connectionStatePublisher: AnyPublisher<ConnectionState, Never> {
        $connectionState.eraseToAnyPublisher()
    }
    @Published private(set) var connectionState = ConnectionState.notConnected(nil)

    var clientUserConnected: Bool { userDataStorage.clientUserData != nil }

    var connectionMode: ConnectionMode

    private let userDataStorage: UserDataStorage
    private var storage: Set<AnyCancellable> = []

    init(injector: Injector) {
        userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        connectionMode = .sso(.init(appManagedFields: [], loginRequired: { }, modifyUser: { _ in }))
        let postFeedsStore = injector.getInjected(identifiedBy: Injected.postFeedsStore)

        userDataStorage.$userData
            .removeDuplicates()
            .sink { [unowned self] in
                if let userData = $0 {
                    connectionState = .connected(
                        User(
                            profile: CurrentUserProfile(
                                storableProfile: StorableCurrentUserProfile.create(
                                    id: "profileId", userId: userData.id, nickname: "nickname"),
                                gamificationLevels: [],
                                postFeedsStore: postFeedsStore),
                            jwtToken: userData.jwtToken), nil)
                } else {
                    connectionState = .notConnected(nil)
                }
            }.store(in: &storage)
    }

    func mock(connected: Bool) {
        if connected {
            userDataStorage.store(userData: UserDataStorage.UserData(id: "fake_id", jwtToken: "fake_token"))
        } else {
            userDataStorage.store(userData: nil)
        }
    }

    func logout() async throws {
        userDataStorage.store(userData: nil)
    }

    func logoutBeforeCommunitySwitch() async throws {
        userDataStorage.store(userData: nil)
    }

    func onAuthenticatedCallFailed() async throws {
        try await logout()
    }

    func connectUser(_ user: ClientUser, tokenProvider: @escaping () async throws -> String) async throws { }

    func disconnectUser() async throws { }

    func linkClientUserToOctopusUser() async throws(ExchangeTokenError) { }

    func refreshEntitlements() async throws(RefreshEntitlementsCoreError) { }
    func reconnectAfterAccountDeletion() async throws(ConnectionError) { }
}
