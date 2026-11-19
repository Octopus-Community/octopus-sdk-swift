//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusDependencyInjection
import OctopusRemoteClient
@testable import OctopusCore

/// A failed refresh of the community config is retried a bounded number of times, then only once the app comes back.
struct ConfigRepositoryRetryTests {

    private let injector: Injector
    private let mockNetworkMonitor: MockNetworkMonitor
    private let mockAppStateMonitor: MockAppStateMonitor
    private let mockApiKeyService: MockApiKeyService

    /// Long enough for a retry that should not happen to show up: the quick retries take 0.1 s in all.
    private let noRetryWait: TimeInterval = 0.5

    init() {
        injector = Injector()
        injector.register { _ in try! ConfigCoreDataStack(inRam: true) }
        injector.register { CommunityConfigDatabase(injector: $0) }
        injector.register { UserConfigDatabase(injector: $0) }
        injector.registerMocks(.remoteClient, .networkMonitor, .appStateMonitor, .authProvider, .securedStorage,
                               .communityClosure)
        injector.register { UserDataStorage(injector: $0) }

        mockNetworkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor) as! MockNetworkMonitor
        mockAppStateMonitor = injector.getInjected(identifiedBy: Injected.appStateMonitor) as! MockAppStateMonitor
        mockApiKeyService = (injector.getInjected(identifiedBy: Injected.remoteClient).apiKeyService
                             as! MockApiKeyService)
    }

    @Test func testRecoversFromAPassingFailureWithAQuickRetry() async throws {
        mockApiKeyService.injectNextGetConfigError(.timeout)
        mockApiKeyService.injectNextGetConfigResponse(.init())
        let repository = makeRepository()

        try await expectWithTimeout(repository.communityConfig != nil)
        #expect(mockApiKeyService.getConfigCallCount == 2)
    }

    @Test func testStopsRetryingWhileTheAppStaysActive() async throws {
        failThreeTimes()
        let repository = makeRepository()
        try await expectWithTimeout(mockApiKeyService.getConfigCallCount == 3)

        try await Task.sleep(nanoseconds: .secondsToNano(noRetryWait))
        #expect(mockApiKeyService.getConfigCallCount == 3)
        withExtendedLifetime(repository) { }
    }

    @Test func testRefreshesAgainWhenTheAppComesBackAfterTheRetriesFailed() async throws {
        failThreeTimes()
        let repository = makeRepository()
        try await expectWithTimeout(mockApiKeyService.getConfigCallCount == 3)
        try await Task.sleep(nanoseconds: .secondsToNano(noRetryWait))

        mockApiKeyService.injectNextGetConfigResponse(.init())
        mockAppStateMonitor.appState = .background
        try await Task.sleep(nanoseconds: .secondsToNano(noRetryWait))
        #expect(mockApiKeyService.getConfigCallCount == 3)

        mockAppStateMonitor.appState = .active
        try await expectWithTimeout(repository.communityConfig != nil)
        #expect(mockApiKeyService.getConfigCallCount == 4)
    }

    @Test func testRefreshesAgainWhenTheNetworkComesBackAfterTheRetriesFailed() async throws {
        failThreeTimes()
        let repository = makeRepository()
        try await expectWithTimeout(mockApiKeyService.getConfigCallCount == 3)
        try await Task.sleep(nanoseconds: .secondsToNano(noRetryWait))

        mockApiKeyService.injectNextGetConfigResponse(.init())
        mockNetworkMonitor.connectionAvailable = false
        try await Task.sleep(nanoseconds: .secondsToNano(noRetryWait))
        #expect(mockApiKeyService.getConfigCallCount == 3)

        mockNetworkMonitor.connectionAvailable = true
        try await expectWithTimeout(repository.communityConfig != nil)
        #expect(mockApiKeyService.getConfigCallCount == 4)
    }

    @Test func testAnErrorTheServerKeepsReturningIsAskedAgainOnlyWhenTheAppComesBack() async throws {
        failThreeTimes()
        let repository = makeRepository()
        try await expectWithTimeout(mockApiKeyService.getConfigCallCount == 3)
        try await Task.sleep(nanoseconds: .secondsToNano(noRetryWait))

        failThreeTimes()
        mockAppStateMonitor.appState = .background
        mockAppStateMonitor.appState = .active
        try await expectWithTimeout(mockApiKeyService.getConfigCallCount == 6)

        try await Task.sleep(nanoseconds: .secondsToNano(noRetryWait))
        #expect(mockApiKeyService.getConfigCallCount == 6)
        withExtendedLifetime(repository) { }
    }

    /// A quick retry that finds no network used to end the retries: the config was then only asked again on the
    /// next launch.
    @Test func testARetryWithoutNetworkWaitsForTheNetwork() async throws {
        mockApiKeyService.injectNextGetConfigError(.timeout)
        mockApiKeyService.injectNextGetConfigResponse(.init())
        // long enough to lose the network before the first quick retry
        let repository = makeRepository(quickRetryDelays: [0.3, 0.3])
        try await expectWithTimeout(mockApiKeyService.getConfigCallCount == 1)

        mockNetworkMonitor.connectionAvailable = false
        try await Task.sleep(nanoseconds: .secondsToNano(0.8))
        #expect(mockApiKeyService.getConfigCallCount == 1)

        mockNetworkMonitor.connectionAvailable = true
        try await expectWithTimeout(repository.communityConfig != nil)
        #expect(mockApiKeyService.getConfigCallCount == 2)
    }

    @Test func testRefreshesOnlyOnceWhenTheAppComesBackAfterASuccess() async throws {
        mockApiKeyService.injectNextGetConfigResponse(.init())
        let repository = makeRepository()
        try await expectWithTimeout(repository.communityConfig != nil)

        mockAppStateMonitor.appState = .background
        mockAppStateMonitor.appState = .active
        try await Task.sleep(nanoseconds: .secondsToNano(noRetryWait))
        #expect(mockApiKeyService.getConfigCallCount == 1)
    }

    /// Online and active, the repository refreshes the config as soon as it is built: inject its answers before.
    private func makeRepository(quickRetryDelays: [TimeInterval] = [0.05, 0.05]) -> ConfigRepositoryDefault {
        ConfigRepositoryDefault(injector: injector, quickRetryDelays: quickRetryDelays)
    }

    /// Makes the refresh and its two quick retries fail, as an error the server keeps returning does.
    private func failThreeTimes() {
        for _ in 0..<3 {
            mockApiKeyService.injectNextGetConfigError(.permissionDenied(reason: nil))
        }
    }
}
