//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import XCTest
import Combine
import OctopusDependencyInjection
import OctopusRemoteClient
@testable import OctopusCore

class AuthenticatedCallProviderTests: XCTestCase {
    /// Object that is tested
    private var authenticatedCallProvider: AuthenticatedCallProvider!

    private var userDataStorage: UserDataStorage!
    private var connectionRepository: MockConnectionRepository!

    override func setUp() {
        let injector = Injector()
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
            try await delay()
            switch connectionRepository.connectionState {
            case .notConnected:
                break // expected result
            default:
                XCTFail("notConnected state expected")
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
            try await delay()
            switch connectionRepository.connectionState {
            case .notConnected:
                break // expected result
            default:
                XCTFail("notConnected state expected")
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
}


private final class MockConnectionRepository: ConnectionRepository, InjectableObject, @unchecked Sendable {
    static let injectedIdentifier = Injected.connectionRepository

    var connectionStatePublisher: AnyPublisher<ConnectionState, Never> {
        $connectionState.eraseToAnyPublisher()
    }
    @Published private(set) var connectionState = ConnectionState.notConnected

    var connectionMode: ConnectionMode

    private let userDataStorage: UserDataStorage
    private var storage: Set<AnyCancellable> = []

    init(injector: Injector) {
        userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        connectionMode = .octopus(deepLink: nil) // for simplicity purpose
        let postFeedsStore = injector.getInjected(identifiedBy: Injected.postFeedsStore)

        userDataStorage.$userData
            .removeDuplicates()
            .sink { [unowned self] in
                if let userData = $0 {
                    connectionState = .connected(
                        User(
                            profile: CurrentUserProfile(
                                storableProfile: StorableCurrentUserProfile(
                                    id: "profileId", userId: userData.id, nickname: "nickname", email: nil, bio: nil,
                                    pictureUrl: nil, descPostFeedId: "", ascPostFeedId: "", blockedProfileIds: []),
                                postFeedsStore: postFeedsStore),
                            jwtToken: userData.jwtToken))
                } else {
                    connectionState = .notConnected
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

    func sendMagicLink(to email: String) async throws(MagicLinkEmailEntryError) { }

    func cancelMagicLink() { }

    func checkMagicLinkConfirmed() async throws(MagicLinkConfirmationError) -> Bool { return false }

    func logout() async throws {
        userDataStorage.store(userData: nil)
    }

    func deleteAccount(reason: DeleteAccountReason) async throws(AuthenticatedActionError) { }

    func connectUser(_ user: ClientUser, tokenProvider: @escaping () async throws -> String) async throws { }

    func disconnectUser() async throws { }

    func linkClientUserToOctopusUser() async throws(ExchangeTokenError) { }
}
