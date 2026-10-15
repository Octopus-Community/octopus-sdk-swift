//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusDependencyInjection
@testable import OctopusCore

/// A config repository can be released while the work it started is still pending, as when switching community
/// releases the previous core: that work must not reach the released repository.
struct ConfigRepositoryLifetimeTests {

    /// Online and active, `init` starts a task that refreshes the community config, and the database publishers
    /// deliver their values on the main queue. Releasing the repository off the main thread, as a community switch
    /// can, must neither crash nor leave the repository retained, whether that work runs before, during or after the
    /// release.
    ///
    /// Which of these happens is up to the scheduler: many repositories are built and released to make the late ones,
    /// those that used to crash, happen.
    @Test func aRepositoryReleasedWithPendingWorkIsLeftAlone() async throws {
        let injector = makeInjector()
        let apiKeyService = try #require(
            injector.getInjected(identifiedBy: Injected.remoteClient).apiKeyService as? MockApiKeyService)
        let count = 200
        // Answered, so that a refresh started while its repository is alive succeeds instead of retrying.
        for _ in 0..<count {
            apiKeyService.injectNextGetConfigResponse(.init())
        }

        var releasedRepositories = [WeakReference]()
        for _ in 0..<count {
            let repository = ConfigRepositoryDefault(injector: injector)
            releasedRepositories.append(WeakReference(repository))
        }

        // Give the late deliveries and refresh tasks time to run, then let the refreshes that started before a
        // release end and let their repository go.
        try await Task.sleep(nanoseconds: .secondsToNano(0.2))
        try await expectWithTimeout(releasedRepositories.allSatisfy { $0.object == nil })
    }

    /// A failed refresh plans another one a few seconds later. Releasing the repository meanwhile must let it go, not
    /// keep it alive, and retrying, until then.
    @Test func aRepositoryReleasedWithAPlannedRetryIsLeftAlone() async throws {
        let injector = makeInjector()
        // In the background, so that init starts no refresh of its own to run alongside the one below.
        try #require(injector.getInjected(identifiedBy: Injected.appStateMonitor) as? MockAppStateMonitor)
            .appState = .background
        var repository: ConfigRepositoryDefault? = ConfigRepositoryDefault(injector: injector)
        // No answer injected: the refresh fails and plans a retry in 5 seconds.
        try? await repository?.refreshCommunityConfig()
        let releasedRepository = WeakReference(try #require(repository))

        repository = nil

        try await expectWithTimeout(timeout: 1, releasedRepository.object == nil)
    }

    private func makeInjector() -> Injector {
        let injector = Injector()
        injector.register { _ in try! ConfigCoreDataStack(inRam: true) }
        injector.registerMocks(.remoteClient, .securedStorage, .networkMonitor, .appStateMonitor)
        injector.register { UserDataStorage(injector: $0) }
        injector.register { AuthenticatedCallProviderDefault(injector: $0) }
        injector.register { UserConfigDatabase(injector: $0) }
        injector.register { CommunityConfigDatabase(injector: $0) }
        return injector
    }
}

private final class WeakReference {
    weak var object: AnyObject?

    init(_ object: AnyObject) {
        self.object = object
    }
}
