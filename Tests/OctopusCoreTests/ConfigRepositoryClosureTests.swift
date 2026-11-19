//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Testing
import OctopusGrpcModels
import OctopusDependencyInjection
@testable import OctopusCore

/// A closed community is checked again only once its date has come, at launch or back in the foreground; nothing
/// else may fetch the config or the access meanwhile.
@Suite(.serialized)
struct ConfigRepositoryClosureTests {
    private let userDefaults = UserDefaults(suiteName: "ConfigRepositoryClosureTests-\(UUID())")!

    @Test func aStoredClosureBeforeItsDateMakesNoGetConfigAtLaunch() async throws {
        let injector = makeInjector(storedClosureDate: Date().addingTimeInterval(3_600))

        let repository = ConfigRepositoryDefault(injector: injector)

        try await Task.sleep(nanoseconds: .secondsToNano(0.2))
        #expect(apiKeyService(injector).getConfigCalls.isEmpty)
        withExtendedLifetime(repository) { }
    }

    @Test func aStoredClosureAfterItsDateMakesOneBypassingGetConfig() async throws {
        let injector = makeInjector(storedClosureDate: Date().addingTimeInterval(-1))
        apiKeyService(injector).injectNextGetConfigResponse(stillClosedResponse())

        let repository = ConfigRepositoryDefault(injector: injector)

        try await expectWithTimeout(apiKeyService(injector).getConfigCalls == [true])
        withExtendedLifetime(repository) { }
    }

    @Test func comingBackToTheForegroundAfterTheDateChecksAgain() async throws {
        let injector = makeInjector(storedClosureDate: Date().addingTimeInterval(3_600))
        apiKeyService(injector).injectNextGetConfigResponse(stillClosedResponse())
        let repository = ConfigRepositoryDefault(injector: injector)
        repository.now = { Date().addingTimeInterval(7_200) }

        appStateMonitor(injector).appState = .background
        appStateMonitor(injector).appState = .active

        try await expectWithTimeout(apiKeyService(injector).getConfigCalls == [true])
        withExtendedLifetime(repository) { }
    }

    @Test func comingBackToTheForegroundBeforeTheDateMakesNoCall() async throws {
        let injector = makeInjector(storedClosureDate: Date().addingTimeInterval(3_600))
        let repository = ConfigRepositoryDefault(injector: injector)

        for _ in 0..<3 {
            appStateMonitor(injector).appState = .background
            appStateMonitor(injector).appState = .active
        }

        try await Task.sleep(nanoseconds: .secondsToNano(0.2))
        #expect(apiKeyService(injector).getConfigCalls.isEmpty)
        withExtendedLifetime(repository) { }
    }

    @Test func aLocaleRefreshWhileClosedMakesNoCall() async throws {
        let injector = makeInjector(storedClosureDate: Date().addingTimeInterval(3_600))
        let repository = ConfigRepositoryDefault(injector: injector)

        try await repository.refreshCommunityConfig()

        #expect(apiKeyService(injector).getConfigCalls.isEmpty)
    }

    @Test func anAccessRefreshWhileClosedMakesNoCall() async throws {
        let injector = makeInjector(storedClosureDate: Date().addingTimeInterval(3_600))
        let repository = ConfigRepositoryDefault(injector: injector)

        let read = try await repository.refreshCommunityAccess()

        #expect(read == nil)
        #expect(userService(injector).canAccessCommunityCallCount == 0)
    }

    /// The caller decides on the access just read: the published one only follows a main queue turn later.
    @Test func anAccessRefreshStoresAndReturnsTheReason() async throws {
        let injector = makeInjector(storedClosureDate: nil)
        userService(injector).injectNextCanAccessCommunityResponse(.with {
            $0.canAccessCommunity = false
            $0.communityDisabledMessage = "Bye"
            $0.accountDeleted = .init()
        })
        let repository = ConfigRepositoryDefault(injector: injector)

        let read = try await repository.refreshCommunityAccess()

        let expected = UserConfig(canAccessCommunity: false, accessDeniedMessage: "Bye",
                                  noAccessReason: .accountDeleted)
        #expect(read == expected)
        #expect(try await storedUserConfig(injector) == expected)
    }

    /// An access asked before the closure, answered after it, is not stored: the row keeps the open community's
    /// access for the reopening.
    @Test func anAccessAnswerArrivingAfterTheClosureIsDropped() async throws {
        let injector = makeInjector(storedClosureDate: nil)
        let closureRepository = injector.getInjected(identifiedBy: Injected.communityClosureRepository)
        userService(injector).injectNextCanAccessCommunityResponse(.with { $0.canAccessCommunity = true })
        let closedConfig = stillClosedResponse().apiKeyConfig
        userService(injector).canAccessCommunityHook = {
            await closureRepository.handle(config: closedConfig)
        }
        let monitor = CommunityAccessMonitor(injector: injector)

        try await monitor.getCommunityAccess()

        #expect(try await storedUserConfig(injector) == nil)
    }

    /// The access row keeps the open community's access through the closure: once it reopens, the community shows at
    /// once, without waiting for the access call, which can fail or wait for a guest to be connected.
    @Test func reopeningShowsTheOpenCommunityAccessAtOnce() async throws {
        let (injector, repository) = try await makeOpenRepositoryAfterItsLaunchRefresh()
        let closureRepository = injector.getInjected(identifiedBy: Injected.communityClosureRepository)
        try await injector.getInjected(identifiedBy: Injected.userConfigDatabase)
            .upsert(canAccessCommunity: true, message: nil)
        try await expectWithTimeout(repository.userConfig?.canAccessCommunity == true)
        await closureRepository.handle(config: stillClosedResponse().apiKeyConfig)
        try await expectWithTimeout(repository.userConfig?.accessDeniedMessage == "Closed msg")

        await closureRepository.handle(config: Com_Octopuscommunity_ApiKeyConfig())

        try await expectWithTimeout(repository.userConfig?.canAccessCommunity == true)
        #expect(repository.userConfig?.accessDeniedMessage == nil)
    }

    /// The access row can be missing while the closure is stored: a community switch wipes the config store, and the
    /// app can be killed during the purge. The closure message is shown all the same.
    @Test func aStoredClosureShowsItsMessageWithoutAnAccessRow() {
        let injector = makeInjector(storedClosureDate: Date().addingTimeInterval(3_600))

        let repository = ConfigRepositoryDefault(injector: injector)

        #expect(repository.userConfig?.canAccessCommunity == false)
        #expect(repository.userConfig?.accessDeniedMessage == "Closed msg")
    }

    @Test func aStoredClosureWithoutAnAccessRowPublishesItsKind() {
        let injector = makeInjector(storedClosureDate: Date().addingTimeInterval(3_600), kind: .temporarilyDisabled)

        let repository = ConfigRepositoryDefault(injector: injector)

        #expect(repository.userConfig == UserConfig(canAccessCommunity: false, accessDeniedMessage: "Closed msg",
                                                    noAccessReason: .temporarilyDisabled))
    }

    /// The closure comes first, reason included, whatever the access call stored before it.
    @Test(arguments: [(CommunityClosure.Kind.closed, CommunityNoAccessReason.closed),
                      (.temporarilyDisabled, .temporarilyDisabled)])
    func aStoredClosurePublishesItsKindOverAStoredReason(kind: CommunityClosure.Kind,
                                                         expected: CommunityNoAccessReason) async throws {
        let injector = makeInjector(storedClosureDate: Date().addingTimeInterval(3_600), kind: kind)
        try await injector.getInjected(identifiedBy: Injected.userConfigDatabase).upsert(
            UserConfig(canAccessCommunity: false, accessDeniedMessage: "Cohort msg", noAccessReason: .cohort))

        let repository = ConfigRepositoryDefault(injector: injector)

        // Long enough for the stored row to be delivered by the database
        try await Task.sleep(nanoseconds: .secondsToNano(0.2))
        #expect(repository.userConfig == UserConfig(canAccessCommunity: false, accessDeniedMessage: "Closed msg",
                                                    noAccessReason: expected))
    }

    /// A closure does not write the access row: once the community is open again, the reason stored before it
    /// is the one in force.
    @Test func reopeningPublishesTheStoredReasonAgain() async throws {
        let injector = makeInjector(storedClosureDate: Date().addingTimeInterval(3_600))
        let stored = UserConfig(canAccessCommunity: false, accessDeniedMessage: "Cohort msg",
                                noAccessReason: .memberExcluded)
        try await injector.getInjected(identifiedBy: Injected.userConfigDatabase).upsert(stored)
        let repository = ConfigRepositoryDefault(injector: injector)
        #expect(repository.userConfig?.noAccessReason == .closed)

        await injector.getInjected(identifiedBy: Injected.communityClosureRepository).handle(config: .init())

        try await expectWithTimeout(repository.userConfig == stored)
    }

    /// The closure is sent from the thread that changes it, and the user config is published a main queue turn
    /// later, from the closure read again there: a main queue that runs while the reopening thread is still sending
    /// must read the new closure, or nothing publishes the community open after. The subscribers below hold that
    /// thread while it sends, until the main queue has run what was sent before them. Combine calls the subscribers
    /// of a subject in no set order: with enough of them, some are called after the repository's.
    @Test func reopeningPublishesTheStoredReasonWhenTheMainQueueRunsWhileTheClosureIsSent() async throws {
        let injector = makeInjector(storedClosureDate: Date().addingTimeInterval(3_600))
        let closureRepository = injector.getInjected(identifiedBy: Injected.communityClosureRepository)
        let stored = UserConfig(canAccessCommunity: false, accessDeniedMessage: "Cohort msg",
                                noAccessReason: .memberExcluded)
        try await injector.getInjected(identifiedBy: Injected.userConfigDatabase).upsert(stored)
        let repository = ConfigRepositoryDefault(injector: injector)
        let heldSends = holdingTheSendsUntilTheMainQueueRan(closureRepository)

        await closureRepository.handle(config: .init())

        try await expectWithTimeout(repository.userConfig == stored)
        withExtendedLifetime(heldSends) { }
    }

    /// The same, closing: the community must not stay published open.
    @Test func closingPublishesTheClosureWhenTheMainQueueRunsWhileItIsSent() async throws {
        let injector = makeInjector(storedClosureDate: nil)
        let closureRepository = injector.getInjected(identifiedBy: Injected.communityClosureRepository)
        try await injector.getInjected(identifiedBy: Injected.userConfigDatabase)
            .upsert(canAccessCommunity: true, message: nil)
        let repository = ConfigRepositoryDefault(injector: injector)
        try await expectWithTimeout(repository.userConfig?.canAccessCommunity == true)
        let heldSends = holdingTheSendsUntilTheMainQueueRan(closureRepository)

        await closureRepository.handle(config: stillClosedResponse().apiKeyConfig)

        try await expectWithTimeout(repository.userConfig?.accessDeniedMessage == "Closed msg")
        withExtendedLifetime(heldSends) { }
    }

    /// The host app reads the reason right after the SDK is initialized, before the database answers.
    ///
    /// On the main thread, as a host app builds the SDK: the database answers on the main queue, here with no row,
    /// and cannot do so between the init and the read.
    @MainActor
    @Test func theReasonOfThePreviousLaunchIsPublishedAtInit() {
        let injector = makeInjector(storedClosureDate: nil)
        UserCommunityAccessSyncStore(userDefaults: userDefaults).set(
            UserConfig(canAccessCommunity: false, accessDeniedMessage: "Bye", noAccessReason: .accountDeleted))

        let repository = ConfigRepositoryDefault(
            injector: injector, accessSyncStore: UserCommunityAccessSyncStore(userDefaults: userDefaults))

        #expect(repository.userConfig?.canAccessCommunity == false)
        #expect(repository.userConfig?.noAccessReason == .accountDeleted)
    }

    /// The config answer is handled off the main thread, and main-actor view models subscribe to the user config:
    /// the closure must reach them on the main thread, as the database values do.
    @Test func aClosureReceivedOffTheMainThreadPublishesTheUserConfigOnTheMainThread() async throws {
        let injector = makeInjector(storedClosureDate: nil)
        let closureRepository = injector.getInjected(identifiedBy: Injected.communityClosureRepository)
        let repository = ConfigRepositoryDefault(injector: injector)
        let received = ReceivedUserConfigs()
        let cancellable = repository.userConfigPublisher
            .dropFirst()
            .sink { received.append(isMainThread: Thread.isMainThread, userConfig: $0) }
        let closedConfig = stillClosedResponse().apiKeyConfig

        await Task.detached { await closureRepository.handle(config: closedConfig) }.value

        try await expectWithTimeout(received.values.contains { $0.userConfig?.accessDeniedMessage == "Closed msg" })
        #expect(received.values.allSatisfy { $0.isMainThread })
        withExtendedLifetime((repository, cancellable)) { }
    }

    @Test func anOpenCommunityStillFetchesTheConfigOnceAtLaunch() async throws {
        let injector = makeInjector(storedClosureDate: nil)
        apiKeyService(injector).injectNextGetConfigResponse(.init())
        let repository = ConfigRepositoryDefault(injector: injector)
        try await expectWithTimeout(apiKeyService(injector).getConfigCalls == [false])

        appStateMonitor(injector).appState = .background
        appStateMonitor(injector).appState = .active

        try await Task.sleep(nanoseconds: .secondsToNano(0.2))
        #expect(apiKeyService(injector).getConfigCalls == [false])
        withExtendedLifetime(repository) { }
    }

    // MARK: Refreshes running together

    /// Launch, the foreground, a language change and a refused call can each ask for a due check at once: they share
    /// the one in flight, so one `GetConfig` passes the gate.
    @Test func dueChecksRunningTogetherSendOneGetConfig() async throws {
        let injector = makeInjector(storedClosureDate: Date().addingTimeInterval(3_600))
        apiKeyService(injector).injectNextGetConfigResponse(stillClosedResponse())
        apiKeyService(injector).getConfigDelay = 0.3
        let repository = ConfigRepositoryDefault(injector: injector)
        repository.now = { Date().addingTimeInterval(7_200) }

        async let first: Void = repository.refreshCommunityConfig()
        async let second: Void = repository.refreshCommunityConfig()
        _ = try await (first, second)

        #expect(apiKeyService(injector).getConfigCalls == [true])
        // The answer moved the date: the next check waits for it.
        try await repository.refreshCommunityConfig()
        #expect(apiKeyService(injector).getConfigCalls == [true])
    }

    @Test func refreshesOfAnOpenCommunityRunningTogetherSendOneGetConfig() async throws {
        let (injector, repository) = try await makeOpenRepositoryAfterItsLaunchRefresh()
        apiKeyService(injector).injectNextGetConfigResponse(.init())
        apiKeyService(injector).getConfigDelay = 0.3

        async let first: Void = repository.refreshCommunityConfig()
        async let second: Void = repository.refreshCommunityConfig()
        _ = try await (first, second)

        #expect(apiKeyService(injector).getConfigCalls == [false, false])
    }

    // MARK: Closed community refusals

    /// A community closed while the app runs first shows as calls the server refuses because of the closure.
    @Test func aClosedCommunityRefusalChecksTheConfigAndClosesTheCommunity() async throws {
        let (injector, repository) = try await makeOpenRepositoryAfterItsLaunchRefresh()
        apiKeyService(injector).injectNextGetConfigResponse(stillClosedResponse())

        remoteClient(injector).communityClosedHandler?()

        try await expectWithTimeout(repository.userConfig?.accessDeniedMessage == "Closed msg")
        #expect(apiKeyService(injector).getConfigCalls == [false, false])
    }

    /// The calls running when the community closes are all refused: one check answers them all.
    @Test func refusalsArrivingTogetherCheckTheConfigOnce() async throws {
        let (injector, repository) = try await makeOpenRepositoryAfterItsLaunchRefresh()
        apiKeyService(injector).injectNextGetConfigResponse(.init())

        for _ in 0..<3 {
            remoteClient(injector).communityClosedHandler?()
        }

        try await expectWithTimeout(apiKeyService(injector).getConfigCalls == [false, false])
        try await Task.sleep(nanoseconds: .secondsToNano(0.2))
        #expect(apiKeyService(injector).getConfigCalls == [false, false])
        withExtendedLifetime(repository) { }
    }

    /// The server names the closure: no delay is kept between two checks, only one runs at a time.
    @Test func aRefusalAfterTheCheckEndedChecksTheConfigAgain() async throws {
        let (injector, repository) = try await makeOpenRepositoryAfterItsLaunchRefresh()
        apiKeyService(injector).injectNextGetConfigResponse(.init())
        apiKeyService(injector).injectNextGetConfigResponse(.init())
        remoteClient(injector).communityClosedHandler?()
        try await expectWithTimeout(apiKeyService(injector).getConfigCalls == [false, false])
        try await Task.sleep(nanoseconds: .secondsToNano(0.2))

        remoteClient(injector).communityClosedHandler?()

        try await expectWithTimeout(apiKeyService(injector).getConfigCalls == [false, false, false])
        withExtendedLifetime(repository) { }
    }

    /// Only the check due at its date may reach the server while the community is closed.
    @Test func aRefusalWhileClosedMakesNoCall() async throws {
        let injector = makeInjector(storedClosureDate: Date().addingTimeInterval(3_600))
        let repository = ConfigRepositoryDefault(injector: injector)

        remoteClient(injector).communityClosedHandler?()

        try await Task.sleep(nanoseconds: .secondsToNano(0.2))
        #expect(apiKeyService(injector).getConfigCalls.isEmpty)
        withExtendedLifetime(repository) { }
    }

    // MARK: Helpers

    /// An open community whose config was fetched at launch, so that the next calls are the ones under test.
    private func makeOpenRepositoryAfterItsLaunchRefresh() async throws -> (Injector, ConfigRepositoryDefault) {
        let injector = makeInjector(storedClosureDate: nil)
        apiKeyService(injector).injectNextGetConfigResponse(.init())
        // A launch answer that takes a while, as on a slow runner: the call is counted long before it ends.
        apiKeyService(injector).getConfigDelay = 0.3
        let repository = ConfigRepositoryDefault(injector: injector)
        // Ended, not only sent: a refresh asked while it runs joins it instead of sending its own `GetConfig`.
        try await expectWithTimeout(apiKeyService(injector).getConfigCalls == [false] && !repository.isRefreshInFlight)
        apiKeyService(injector).getConfigDelay = 0
        return (injector, repository)
    }

    /// Subscribers of the closure that each hold the sending thread until the main queue ran what was sent before.
    private func holdingTheSendsUntilTheMainQueueRan(_ closureRepository: CommunityClosureRepository)
    -> [AnyCancellable] {
        (0..<30).map { _ in
            closureRepository.closurePublisher
                .dropFirst()
                .sink { _ in DispatchQueue.main.sync { } }
        }
    }

    private func remoteClient(_ injector: Injector) -> MockRemoteClient {
        injector.getInjected(identifiedBy: Injected.remoteClient) as! MockRemoteClient
    }

    private func makeInjector(storedClosureDate: Date?, kind: CommunityClosure.Kind = .closed) -> Injector {
        let store = CommunityClosureStore(apiKey: "apiKey", userDefaults: userDefaults)
        store.set(storedClosureDate.map { CommunityClosure(kind: kind, message: "Closed msg", nextCheckDate: $0) })
        let injector = Injector()
        injector.register { _ in try! ConfigCoreDataStack(inRam: true) }
        injector.registerMocks(.remoteClient, .securedStorage, .networkMonitor, .appStateMonitor, .authProvider)
        injector.register { UserDataStorage(injector: $0) }
        injector.register { UserConfigDatabase(injector: $0) }
        injector.register { CommunityConfigDatabase(injector: $0) }
        injector.registerCommunityClosure(store: store)
        injector.getInjected(identifiedBy: Injected.userDataStorage)
            .store(userData: .init(id: "userId", jwtToken: "token"))
        return injector
    }

    private func stillClosedResponse() -> Com_Octopuscommunity_GetConfigResponse {
        .with {
            $0.apiKeyConfig.closed = .with {
                $0.message = "Closed msg"
                $0.nextCheckAt = UInt64(Date().addingTimeInterval(86_400).timeIntervalSince1970 * 1000)
            }
        }
    }

    private func apiKeyService(_ injector: Injector) -> MockApiKeyService {
        injector.getInjected(identifiedBy: Injected.remoteClient).apiKeyService as! MockApiKeyService
    }

    private func userService(_ injector: Injector) -> MockUserService {
        injector.getInjected(identifiedBy: Injected.remoteClient).userService as! MockUserService
    }

    private func appStateMonitor(_ injector: Injector) -> MockAppStateMonitor {
        injector.getInjected(identifiedBy: Injected.appStateMonitor) as! MockAppStateMonitor
    }

    private func storedUserConfig(_ injector: Injector) async throws -> UserConfig? {
        let context = injector.getInjected(identifiedBy: Injected.configCoreDataStack).saveContext
        return try await context.performAsync {
            try context.fetch(UserConfigEntity.fetch()).first.flatMap(UserConfig.init(from:))
        }
    }
}

/// The user configs a subscriber received, with whether each came on the main thread. Locked: the values arrive on
/// whichever thread published them.
private final class ReceivedUserConfigs: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValues: [(isMainThread: Bool, userConfig: UserConfig?)] = []

    var values: [(isMainThread: Bool, userConfig: UserConfig?)] {
        lock.lock()
        defer { lock.unlock() }
        return storedValues
    }

    func append(isMainThread: Bool, userConfig: UserConfig?) {
        lock.lock()
        defer { lock.unlock() }
        storedValues.append((isMainThread, userConfig))
    }
}
