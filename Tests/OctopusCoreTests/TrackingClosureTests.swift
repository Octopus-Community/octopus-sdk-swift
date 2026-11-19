//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusGrpcModels
import OctopusDependencyInjection
@testable import OctopusCore

/// Nothing is recorded while the community is closed: the events would otherwise be sent all at once when it
/// reopens.
@Suite(.serialized)
final class TrackingClosureTests {
    private let injector = Injector()
    private let suiteName = "OctopusSdkTests.TrackingClosure.\(UUID().uuidString)"
    private let userDefaults: UserDefaults
    private let trackingRepository: TrackingRepository
    private let eventsDatabase: EventsDatabase
    private let closureRepository: CommunityClosureRepository

    init() {
        userDefaults = UserDefaults(suiteName: suiteName)!
        injector.register { _ in try! TrackingCoreDataStack(inRam: true) }
        injector.register { _ in try! ConfigCoreDataStack(inRam: true) }
        injector.register { EventsDatabase(injector: $0) }
        injector.register { UserConfigDatabase(injector: $0) }
        injector.registerMocks(.remoteClient, .authProvider, .appStateMonitor, .configRepository,
                               .backgroundTaskProvider, .communityClosure)
        injector.register { ToastsRepository(injector: $0) }
        injector.register { GamificationRepository(injector: $0) }
        injector.register { SdkEventsEmitter(injector: $0) }
        injector.register { VideosRepository(injector: $0) }
        injector.register { [userDefaults] in TrackingRepository(injector: $0, userDefaults: userDefaults) }

        trackingRepository = injector.getInjected(identifiedBy: Injected.trackingRepository)
        eventsDatabase = injector.getInjected(identifiedBy: Injected.eventsDatabase)
        closureRepository = injector.getInjected(identifiedBy: Injected.communityClosureRepository)
    }

    deinit {
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    @Test func noEventIsStoredWhileClosed() async throws {
        await close()

        trackingRepository.trackTranslationButtonHit(translationDisplayed: true)
        trackingRepository.set(hasAccessToCommunity: true)

        #expect(try await settledEvents().isEmpty)
    }

    @Test func aCustomEventWhileClosedIsDroppedWithoutError() async throws {
        await close()

        try await trackingRepository.track(customEvent: CustomEvent(name: "event"))

        #expect(try await settledEvents().isEmpty)
    }

    @Test func enteringOctopusIsNotCalledWhileClosed() async throws {
        await close()

        trackingRepository.appSessionStarted()
        trackingRepository.octopusUISessionStarted()

        try await Task.sleep(nanoseconds: .secondsToNano(0.3))
        let userService = try #require(
            injector.getInjected(identifiedBy: Injected.remoteClient).userService as? MockUserService)
        #expect(userService.enteringOctopusCallCount == 0)
    }

    /// A session started before the closure and ended by it (the monitors stop) records no end either.
    @Test func aSessionEndedWhileClosedRecordsNoLeavingEvent() async throws {
        trackingRepository.appSessionStarted()
        trackingRepository.octopusUISessionStarted()
        await close()

        trackingRepository.octopusUISessionEnded()
        trackingRepository.appSessionEnded()

        let leavingEvents = try await settledEvents().filter {
            switch $0.content {
            case .leavingApp, .leavingUI: true
            default: false
            }
        }
        #expect(leavingEvents.isEmpty)
    }

    @Test func eventsAreStoredAgainOnceReopened() async throws {
        await close()
        await closureRepository.handle(config: Com_Octopuscommunity_ApiKeyConfig())

        trackingRepository.trackTranslationButtonHit(translationDisplayed: true)

        try await expectWithTimeout { [eventsDatabase] in try await !eventsDatabase.getAllEvents().isEmpty }
    }

    private func close() async {
        var config = Com_Octopuscommunity_ApiKeyConfig()
        config.closed = .with {
            $0.message = "Closed msg"
            $0.nextCheckAt = UInt64(Date().addingTimeInterval(3_600).timeIntervalSince1970 * 1000)
        }
        await closureRepository.handle(config: config)
    }

    /// The events once every pending write has landed, for the checks that something did not happen.
    private func settledEvents() async throws -> [Event] {
        try await Task.sleep(nanoseconds: .secondsToNano(0.3))
        return try await eventsDatabase.getAllEvents()
    }
}
