//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Testing
@testable import OctopusCore
@testable import OctopusUI

/// A member whose account was deleted taps to access the community again: the button waits while the return runs,
/// a failure is told and leaves them able to tap again, and a success lets the community replace the screen.
@MainActor
struct CommunityAccessDeniedViewModelTests {
    private let userConfig = CurrentValueSubject<UserConfig?, Never>(
        UserConfig(canAccessCommunity: false, accessDeniedMessage: "Bye", noAccessReason: .accountDeleted))

    @Test func theButtonIsInactiveWhileTheReturnRuns() async throws {
        let calls = Counter()
        let gate = Gate()
        let viewModel = makeViewModel {
            calls.increment()
            await gate.wait()
        }

        viewModel.accessCommunity()
        try await expectWithTimeout(calls.value == 1)
        #expect(viewModel.isReturning)

        viewModel.accessCommunity()
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(calls.value == 1)

        gate.open()
        try await expectWithTimeout(!viewModel.isReturning)
    }

    @Test func aFailedReturnShowsAnErrorAndAllowsAnotherTap() async throws {
        let calls = Counter()
        let viewModel = makeViewModel {
            calls.increment()
            throw ConnectionError.noNetwork
        }
        let content = viewModel.content

        viewModel.accessCommunity()

        try await expectWithTimeout(viewModel.error == .noNetworkError)
        #expect(!viewModel.isReturning)
        #expect(viewModel.content == content)

        viewModel.accessCommunity()
        try await expectWithTimeout(calls.value == 2)
    }

    @Test func aBanDuringTheReturnShowsTheServerMessage() {
        let ban = ConnectionError.detailedErrors([
            .init(from: ExchangeTokenError.DetailedError(reason: .userBanned, message: "Banned"))
        ])

        #expect(CommunityAccessDeniedViewModel.displayableError(for: ban) == .localizedString("Banned"))
    }

    @Test func anyOtherFailureShowsTheGenericError() {
        let generic = DisplayableString.unknownError

        #expect(CommunityAccessDeniedViewModel.displayableError(for: ConnectionError.unknown(nil)) == generic)
        #expect(CommunityAccessDeniedViewModel.displayableError(for: ConnectionError.jwtError) == generic)
        #expect(CommunityAccessDeniedViewModel.displayableError(for: CancellationError()) == generic)
        #expect(CommunityAccessDeniedViewModel.displayableError(for: ConnectionError.detailedErrors([
            .init(from: ExchangeTokenError.DetailedError(reason: .unknown, message: "Other"))
        ])) == generic)
    }

    /// The community replaces the screen by itself once the access is back. The screen keeps what it displayed
    /// meanwhile, rather than going blank.
    @Test func accessComingBackKeepsWhatTheScreenDisplayed() {
        let viewModel = makeViewModel { }
        let content = viewModel.content

        userConfig.send(UserConfig(canAccessCommunity: true, accessDeniedMessage: nil))

        #expect(content != nil)
        #expect(viewModel.content == content)
    }

    @Test func theAccessIsRefreshedWhenTheScreenAppears() async throws {
        let refreshes = Counter()
        let viewModel = CommunityAccessDeniedViewModel(
            userConfigPublisher: userConfig.eraseToAnyPublisher(),
            refreshAccess: { refreshes.increment() },
            returnAfterAccountDeletion: { })

        try await expectWithTimeout(refreshes.value == 1)
        #expect(viewModel.content?.action == .accessCommunity)
    }

    /// A user left on the screen comes back to the app once their access was opened: the SDK only reads the access
    /// again once a day by itself.
    @Test func theAccessIsRefreshedWhenTheUserComesBackToTheApp() async throws {
        let refreshes = Counter()
        let appComesBack = PassthroughSubject<Void, Never>()
        let viewModel = CommunityAccessDeniedViewModel(
            userConfigPublisher: userConfig.eraseToAnyPublisher(),
            refreshAccess: { refreshes.increment() },
            returnAfterAccountDeletion: { },
            appComesBackPublisher: appComesBack.eraseToAnyPublisher())
        try await expectWithTimeout(refreshes.value == 1)

        appComesBack.send()
        try await expectWithTimeout(refreshes.value == 2)
        appComesBack.send()
        try await expectWithTimeout(refreshes.value == 3)
        withExtendedLifetime(viewModel) { }
    }

    /// The return reads the access itself, with the session it gets.
    @Test func comingBackToTheAppWhileAReturnRunsDoesNotRefreshTheAccess() async throws {
        let refreshes = Counter()
        let gate = Gate()
        let appComesBack = PassthroughSubject<Void, Never>()
        let viewModel = CommunityAccessDeniedViewModel(
            userConfigPublisher: userConfig.eraseToAnyPublisher(),
            refreshAccess: { refreshes.increment() },
            returnAfterAccountDeletion: { await gate.wait() },
            appComesBackPublisher: appComesBack.eraseToAnyPublisher())
        try await expectWithTimeout(refreshes.value == 1)
        viewModel.accessCommunity()
        #expect(viewModel.isReturning)

        appComesBack.send()
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(refreshes.value == 1)
        gate.open()
        try await expectWithTimeout(!viewModel.isReturning)
    }

    private func makeViewModel(returnAfterAccountDeletion: @escaping () async throws -> Void)
    -> CommunityAccessDeniedViewModel {
        CommunityAccessDeniedViewModel(
            userConfigPublisher: userConfig.eraseToAnyPublisher(), refreshAccess: { },
            returnAfterAccountDeletion: returnAfterAccountDeletion)
    }
}

/// Waits for `condition`, which the view model reaches a few main actor turns after a tap.
@MainActor
private func expectWithTimeout(_ condition: @autoclosure () -> Bool,
                               sourceLocation: SourceLocation = #_sourceLocation) async throws {
    let deadline = Date().addingTimeInterval(5)
    while !condition(), Date() < deadline {
        try await Task.sleep(nanoseconds: 5_000_000)
    }
    #expect(condition(), sourceLocation: sourceLocation)
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func increment() {
        lock.lock()
        defer { lock.unlock() }
        count += 1
    }
}

/// Holds the callers of `wait()` until `open()`.
private final class Gate: @unchecked Sendable {
    private let lock = NSLock()
    private var isOpen = false

    func open() {
        lock.lock()
        defer { lock.unlock() }
        isOpen = true
    }

    func wait() async {
        while !isOpenNow {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    private var isOpenNow: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isOpen
    }
}
