//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusDependencyInjection
@testable import OctopusCore

/// A trip to the background shorter than the grace period (a link opened in another app, a quick app switch)
/// keeps the app session and the Octopus UI session. A longer one ends them when the app went to the background.
@Suite(.serialized)
final class AppSessionMonitorTests {
    private let injector = Injector()
    private let clock = TestClock()
    private let suiteName = "OctopusSdkTests.AppSessionMonitor.\(UUID().uuidString)"
    private let userDefaults: UserDefaults
    private let appStateMonitor: MockAppStateMonitor
    private let backgroundTaskProvider: MockBackgroundTaskProvider
    private let trackingRepository: TrackingRepository
    private let eventsDatabase: EventsDatabase

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

        appStateMonitor = injector.getInjected(identifiedBy: Injected.appStateMonitor) as! MockAppStateMonitor
        backgroundTaskProvider = injector.getInjected(identifiedBy: Injected.backgroundTaskProvider)
            as! MockBackgroundTaskProvider
        trackingRepository = injector.getInjected(identifiedBy: Injected.trackingRepository)
        eventsDatabase = injector.getInjected(identifiedBy: Injected.eventsDatabase)
    }

    deinit {
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - App session

    @Test func returnWithinTheGracePeriodKeepsTheAppSession() async throws {
        let monitor = makeMonitor()
        monitor.start()
        try await waitForEvents { $0.enteringApp.count == 1 }

        appStateMonitor.appState = .background
        clock.advance(by: 5)
        appStateMonitor.appState = .active

        let events = try await settledEvents()
        #expect(events.enteringApp.count == 1)
        #expect(events.leavingApp.isEmpty)
        #expect(backgroundTaskProvider.runningTasks.isEmpty)
        monitor.stop()
    }

    @Test func goingToTheBackgroundKeepsTheAppRunningForTheGracePeriod() async throws {
        let monitor = makeMonitor()
        monitor.start()

        appStateMonitor.appState = .background

        #expect(backgroundTaskProvider.runningTasks.count == 1)
        monitor.stop()
        #expect(backgroundTaskProvider.runningTasks.isEmpty)
    }

    @Test func absenceLongerThanTheGracePeriodEndsTheAppSessionWhenTheAppWentToTheBackground() async throws {
        let monitor = makeMonitor(gracePeriod: 0.1)
        monitor.start()
        try await waitForEvents { $0.enteringApp.count == 1 }

        let backgroundDate = clock.now
        appStateMonitor.appState = .background
        clock.advance(by: 60)

        let events = try await waitForEvents { $0.leavingApp.count == 1 }
        #expect(try #require(events.leavingApp.first).endDate.isClose(to: backgroundDate))
        // the background task is released right after the session end is recorded
        try await expectWithTimeout(self.backgroundTaskProvider.runningTasks.isEmpty)

        appStateMonitor.appState = .active
        let restartedEvents = try await waitForEvents { $0.enteringApp.count == 2 }
        #expect(Set(restartedEvents.enteringApp.map(\.appSessionId)).count == 2)
        monitor.stop()
    }

    /// iOS suspends the app soon after it goes to the background: the grace period timer may not have fired
    /// when the app comes back, so the time spent away is checked on return. That time counts while the device
    /// sleeps.
    @Test func returnAfterTheGracePeriodEndsTheAppSessionEvenIfTheTimerDidNotFire() async throws {
        let monitor = makeMonitor()
        monitor.start()
        try await waitForEvents { $0.enteringApp.count == 1 }

        let backgroundDate = clock.now
        appStateMonitor.appState = .background
        clock.advance(by: 11)
        appStateMonitor.appState = .active

        let events = try await waitForEvents { $0.leavingApp.count == 1 && $0.enteringApp.count == 2 }
        #expect(try #require(events.leavingApp.first).endDate.isClose(to: backgroundDate))
        #expect(Set(events.enteringApp.map(\.appSessionId)).count == 2)
        #expect(backgroundTaskProvider.runningTasks.isEmpty)
        monitor.stop()
    }

    /// The SDK can start while the app is in the background (a launch for a silent push, a community switch
    /// made in the background): there is no session to keep, so coming back starts one.
    @Test func returnWithinTheGracePeriodStartsTheAppSessionWhenNoneWasRunning() async throws {
        appStateMonitor.appState = .background
        let monitor = makeMonitor()
        monitor.start()
        #expect(backgroundTaskProvider.runningTasks.isEmpty)

        clock.advance(by: 3)
        appStateMonitor.appState = .active

        try await waitForEvents { $0.enteringApp.count == 1 }
        trackingRepository.octopusUISessionStarted()
        try await waitForEvents { $0.enteringUI.count == 1 }
        monitor.stop()
    }

    /// The grace period is measured with a clock that a change of the device's date does not move.
    @Test func dateChangeAloneDoesNotEndTheAppSession() async throws {
        let monitor = makeMonitor()
        monitor.start()
        try await waitForEvents { $0.enteringApp.count == 1 }

        appStateMonitor.appState = .background
        clock.advance(by: 2, dateChange: 3600)
        appStateMonitor.appState = .active

        let events = try await settledEvents()
        #expect(events.enteringApp.count == 1)
        #expect(events.leavingApp.isEmpty)
        monitor.stop()
    }

    /// Stopping the SDK (a community switch) during the grace period ends the session when the app went to the
    /// background, before the stored events are sent.
    @Test func stopDuringTheGracePeriodEndsTheAppSessionWhenTheAppWentToTheBackground() async throws {
        let monitor = makeMonitor()
        monitor.start()
        try await waitForEvents { $0.enteringApp.count == 1 }

        let backgroundDate = clock.now
        appStateMonitor.appState = .background
        clock.advance(by: 3)
        monitor.stop()

        let events = try await waitForEvents { $0.leavingApp.count == 1 }
        #expect(try #require(events.leavingApp.first).endDate.isClose(to: backgroundDate))
        #expect(backgroundTaskProvider.runningTasks.isEmpty)
    }

    @Test func backgroundTimeRunningOutEndsTheAppSessionWhenTheAppWentToTheBackground() async throws {
        let monitor = makeMonitor()
        monitor.start()
        try await waitForEvents { $0.enteringApp.count == 1 }

        let backgroundDate = clock.now
        appStateMonitor.appState = .background
        clock.advance(by: 4)
        backgroundTaskProvider.expireRunningTasks()

        let events = try await waitForEvents { $0.leavingApp.count == 1 }
        #expect(try #require(events.leavingApp.first).endDate.isClose(to: backgroundDate))
        #expect(backgroundTaskProvider.runningTasks.isEmpty)
        monitor.stop()
    }

    // MARK: - Octopus UI session

    @Test func returnWithinTheGracePeriodKeepsTheOctopusUISession() async throws {
        let monitor = makeMonitor()
        monitor.start()
        trackingRepository.octopusUISessionStarted()
        try await waitForEvents { $0.enteringUI.count == 1 }

        appStateMonitor.appState = .background
        clock.advance(by: 5)
        appStateMonitor.appState = .active

        let events = try await settledEvents()
        #expect(events.enteringUI.count == 1)
        #expect(events.leavingUI.isEmpty)
        monitor.stop()
    }

    @Test func absenceLongerThanTheGracePeriodEndsTheOctopusUISessionWhenTheAppWentToTheBackground() async throws {
        let monitor = makeMonitor(gracePeriod: 0.1)
        monitor.start()
        trackingRepository.octopusUISessionStarted()
        try await waitForEvents { $0.enteringUI.count == 1 }

        let backgroundDate = clock.now
        appStateMonitor.appState = .background
        clock.advance(by: 60)

        let events = try await waitForEvents { $0.leavingUI.count == 1 && $0.leavingApp.count == 1 }
        #expect(try #require(events.leavingUI.first).endDate.isClose(to: backgroundDate))

        // the Octopus UI is still displayed: coming back starts a new UI session with the new app session
        appStateMonitor.appState = .active
        try await waitForEvents { $0.enteringApp.count == 2 && $0.enteringUI.count == 2 }
        monitor.stop()
    }

    /// The Octopus UI can be closed while the app is in the background: its session ends when the app went to
    /// the background, and coming back does not start a new one.
    @Test func octopusUIClosedDuringTheGracePeriodEndsItsSessionWhenTheAppWentToTheBackground() async throws {
        let monitor = makeMonitor()
        monitor.start()
        trackingRepository.octopusUISessionStarted()
        try await waitForEvents { $0.enteringUI.count == 1 }

        let backgroundDate = clock.now
        appStateMonitor.appState = .background
        clock.advance(by: 3)
        trackingRepository.octopusUISessionEnded()
        let events = try await waitForEvents { $0.leavingUI.count == 1 }
        #expect(try #require(events.leavingUI.first).endDate.isClose(to: backgroundDate))

        clock.advance(by: 2)
        appStateMonitor.appState = .active

        let settled = try await settledEvents()
        #expect(settled.enteringUI.count == 1)
        #expect(settled.enteringApp.count == 1)
        #expect(settled.leavingApp.isEmpty)
        monitor.stop()
    }

    /// The Octopus UI can be displayed while the app is in the background: its session starts once the app
    /// comes back.
    @Test func octopusUIDisplayedDuringTheGracePeriodStartsItsSessionOnReturn() async throws {
        let monitor = makeMonitor()
        monitor.start()
        try await waitForEvents { $0.enteringApp.count == 1 }

        appStateMonitor.appState = .background
        trackingRepository.octopusUISessionStarted()
        #expect(try await settledEvents().enteringUI.isEmpty)

        clock.advance(by: 3)
        appStateMonitor.appState = .active

        try await waitForEvents { $0.enteringUI.count == 1 }
        monitor.stop()
    }

    // MARK: - Helpers

    private func makeMonitor(gracePeriod: TimeInterval = 10) -> AppSessionMonitor {
        AppSessionMonitor(injector: injector, gracePeriod: gracePeriod,
                          now: { [clock] in clock.now }, continuousTime: { [clock] in clock.continuousTime })
    }

    @discardableResult
    private func waitForEvents(_ condition: @escaping (TrackedSessionEvents) -> Bool) async throws
    -> TrackedSessionEvents {
        var events = TrackedSessionEvents(events: [])
        try await expectWithTimeout { [eventsDatabase] in
            events = TrackedSessionEvents(events: try await eventsDatabase.getAllEvents())
            return condition(events)
        }
        return events
    }

    /// The events once every pending write has landed, for the checks that something did not happen.
    private func settledEvents() async throws -> TrackedSessionEvents {
        try await Task.sleep(nanoseconds: .secondsToNano(0.3))
        return TrackedSessionEvents(events: try await eventsDatabase.getAllEvents())
    }
}

private struct TrackedSessionEvents {
    struct Ended {
        let sessionId: String?
        let endDate: Date
    }

    let enteringApp: [Event]
    let leavingApp: [Ended]
    let enteringUI: [Event]
    let leavingUI: [Ended]

    init(events: [Event]) {
        var enteringApp = [Event]()
        var leavingApp = [Ended]()
        var enteringUI = [Event]()
        var leavingUI = [Ended]()
        for event in events {
            switch event.content {
            case .enteringApp: enteringApp.append(event)
            case let .leavingApp(_, endDate, _): leavingApp.append(Ended(sessionId: event.appSessionId,
                                                                           endDate: endDate))
            case .enteringUI: enteringUI.append(event)
            case let .leavingUI(_, endDate, _): leavingUI.append(Ended(sessionId: event.uiSessionId,
                                                                         endDate: endDate))
            default: break
            }
        }
        self.enteringApp = enteringApp
        self.leavingApp = leavingApp
        self.enteringUI = enteringUI
        self.leavingUI = leavingUI
    }
}

/// The two clocks the monitor reads: the date written in the events, and the time that measures the grace
/// period, which keeps counting while the device sleeps and does not move when the date is changed.
private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var currentDate = Date()
    private var currentContinuousTime: TimeInterval = 1_000

    var now: Date {
        lock.lock()
        defer { lock.unlock() }
        return currentDate
    }

    var continuousTime: TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        return currentContinuousTime
    }

    /// - Parameters:
    ///   - duration: the time that passes
    ///   - dateChange: an additional change of the device's date, which only moves `now`
    func advance(by duration: TimeInterval, dateChange: TimeInterval = 0) {
        lock.lock()
        defer { lock.unlock() }
        currentDate = currentDate.addingTimeInterval(duration + dateChange)
        currentContinuousTime += duration
    }
}

private extension Date {
    /// Session dates are stored as seconds since 1970 in a `Double`, which rounds them a little.
    func isClose(to other: Date) -> Bool {
        abs(timeIntervalSince1970 - other.timeIntervalSince1970) < 0.001
    }
}
