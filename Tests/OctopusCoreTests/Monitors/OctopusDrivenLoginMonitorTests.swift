//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Testing
import OctopusDependencyInjection
import OctopusRemoteClient
@testable import OctopusCore

@Suite(.serialized)
struct OctopusDrivenLoginMonitorTests {
    private let injector: Injector
    private let postFeedsStore: PostFeedsStore
    private let connectionRepo: StubConnectionRepository

    init() {
        injector = Injector()
        // Build the full graph needed to construct a `CurrentUserProfile`: its post feed is created
        // lazily via `PostFeedsStore.getOrCreate`, which reaches the sibling stores/databases (which in
        // turn reach the connection repository & authenticated-call provider). Mirrors the known-good
        // setup of `AuthenticatedCallProviderTests`.
        injector.register { _ in try! ModelCoreDataStack(inRam: true) }
        injector.registerMocks(.securedStorage, .remoteClient, .networkMonitor, .blockedUserIdsProvider)
        injector.register { _ in StubConnectionRepository() }
        injector.register { UserDataStorage(injector: $0) }
        injector.register { PostFeedsStore(injector: $0) }
        injector.register { CommentFeedsStore(injector: $0) }
        injector.register { ReplyFeedsStore(injector: $0) }
        injector.register { RepliesDatabase(injector: $0) }
        injector.register { CommentsDatabase(injector: $0) }
        injector.register { PostsDatabase(injector: $0) }
        injector.register { FeedItemInfosDatabase(injector: $0) }
        injector.register { AuthenticatedCallProviderDefault(injector: $0) }

        postFeedsStore = injector.getInjected(identifiedBy: Injected.postFeedsStore)
        // swiftlint:disable:next force_cast
        connectionRepo = injector.getInjected(identifiedBy: Injected.connectionRepository) as! StubConnectionRepository
    }

    private func makeMonitor(spy: SpyOctopusDrivenLoginTracker) -> OctopusDrivenLoginMonitor {
        OctopusDrivenLoginMonitor(connectionRepository: connectionRepo, tracker: spy)
    }

    // MARK: - Emits

    @Test
    func emitsOnGuestToRealLogin_withPendingAction() {
        let spy = SpyOctopusDrivenLoginTracker()
        let monitor = makeMonitor(spy: spy)
        monitor.start()

        monitor.notifyLoginRequested(action: .post)
        connectionRepo.set(connectedState(isGuest: true))   // still guest -> no emit
        #expect(spy.actions.isEmpty)
        connectionRepo.set(connectedState(isGuest: false))  // becomes real user -> emit

        #expect(spy.actions == [.post])
    }

    @Test
    func emitsOnDirectLoggedOutToRealLogin() {
        let spy = SpyOctopusDrivenLoginTracker()
        let monitor = makeMonitor(spy: spy)
        monitor.start()

        monitor.notifyLoginRequested(action: .reply)
        connectionRepo.set(connectedState(isGuest: false))

        #expect(spy.actions == [.reply])
    }

    @Test
    func carriesTheMostRecentRequestedAction() {
        let spy = SpyOctopusDrivenLoginTracker()
        let monitor = makeMonitor(spy: spy)
        monitor.start()

        monitor.notifyLoginRequested(action: .post)
        monitor.notifyLoginRequested(action: .reaction)
        connectionRepo.set(connectedState(isGuest: false))

        #expect(spy.actions == [.reaction])
    }

    // MARK: - Does not emit

    @Test
    func noEmit_whenNoLoginRequested() {
        let spy = SpyOctopusDrivenLoginTracker()
        let monitor = makeMonitor(spy: spy)
        monitor.start()

        connectionRepo.set(connectedState(isGuest: false))

        #expect(spy.actions.isEmpty)
    }

    @Test
    func noEmit_whenLoginRequestedButOnlyReachesGuest() {
        let spy = SpyOctopusDrivenLoginTracker()
        let monitor = makeMonitor(spy: spy)
        monitor.start()

        monitor.notifyLoginRequested(action: .comment)
        connectionRepo.set(connectedState(isGuest: true))

        #expect(spy.actions.isEmpty)
    }

    @Test
    func noEmit_whenAlreadyLoggedInAtStart() {
        // User already logged in when the monitor starts: a login request + a mere state republish
        // must not produce a (false) event, because there is no logged-out/guest → logged-in edge.
        connectionRepo.set(connectedState(isGuest: false))
        let spy = SpyOctopusDrivenLoginTracker()
        let monitor = makeMonitor(spy: spy)
        monitor.start()

        monitor.notifyLoginRequested(action: .post)
        connectionRepo.set(connectedState(isGuest: false))

        #expect(spy.actions.isEmpty)
    }

    @Test
    func emitsOnce_pendingIsClearedAfterAttribution() {
        let spy = SpyOctopusDrivenLoginTracker()
        let monitor = makeMonitor(spy: spy)
        monitor.start()

        monitor.notifyLoginRequested(action: .vote)
        connectionRepo.set(connectedState(isGuest: false))
        #expect(spy.actions.count == 1)

        // A logout then a new login WITHOUT a new request must not re-emit.
        connectionRepo.set(.notConnected(nil))
        connectionRepo.set(connectedState(isGuest: false))
        #expect(spy.actions.count == 1)
    }

    // MARK: - Helpers

    private func connectedState(isGuest: Bool) -> ConnectionState {
        let profile = CurrentUserProfile(
            storableProfile: .create(id: "profileId", userId: "userId", nickname: "nickname", isGuest: isGuest),
            gamificationLevels: [],
            postFeedsStore: postFeedsStore)
        return .connected(User(profile: profile, jwtToken: "token"), nil)
    }
}

// MARK: - Test doubles

private final class SpyOctopusDrivenLoginTracker: OctopusDrivenLoginTracker, @unchecked Sendable {
    private(set) var actions: [OctopusDrivenLoginAction] = []

    func trackOctopusDrivenLogin(action: OctopusDrivenLoginAction) {
        actions.append(action)
    }
}

private final class StubConnectionRepository: ConnectionRepository, InjectableObject, @unchecked Sendable {
    static let injectedIdentifier = Injected.connectionRepository

    private let subject = CurrentValueSubject<ConnectionState, Never>(.notConnected(nil))

    func set(_ state: ConnectionState) {
        subject.send(state)
    }

    var connectionState: ConnectionState { subject.value }
    var connectionStatePublisher: AnyPublisher<ConnectionState, Never> { subject.eraseToAnyPublisher() }

    var magicLinkRequestPublisher: AnyPublisher<MagicLinkRequest?, Never> { Just(nil).eraseToAnyPublisher() }
    var magicLinkRequest: MagicLinkRequest? { nil }
    var clientUserConnected: Bool { false }
    var connectionMode: ConnectionMode = .octopus(deepLink: nil)

    func sendMagicLink(to email: String) async throws(MagicLinkEmailEntryError) { }
    func cancelMagicLink() { }
    func checkMagicLinkConfirmed() async throws(MagicLinkConfirmationError) -> Bool { false }
    func onAuthenticatedCallFailed() async throws { }
    func logout(preventReconnection: Bool) async throws { }
    func deleteAccount(reason: DeleteAccountReason) async throws(AuthenticatedActionError) { }
    func connectUser(_ user: ClientUser, tokenProvider: @escaping () async throws -> String) async throws { }
    func disconnectUser() async throws { }
    func linkClientUserToOctopusUser() async throws(ExchangeTokenError) { }
    func refreshEntitlements() async throws(RefreshEntitlementsCoreError) { }
}
