//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import OctopusDependencyInjection

extension Injected {
    static let appSessionMonitor = Injector.InjectedIdentifier<AppSessionMonitor>()
}

/// Class that monitors the app session.
///
/// When the app moves to background, the app session is paused for a grace period. If the app comes back to
/// foreground within that period, the same session goes on. Otherwise, the session ends at the date the app moved
/// to background, and a new session starts when the app comes back to foreground. A trip to the background shorter
/// than the grace period (a link opened in another app, a quick app switch) is then not counted as two sessions,
/// which is also the rule of the Android SDK.
final class AppSessionMonitor: InjectableObject, @unchecked Sendable {
    static let injectedIdentifier = Injected.appSessionMonitor

    private var trackingRepository: TrackingRepository
    private var appStateMonitor: AppStateMonitor
    private let backgroundTaskProvider: BackgroundTaskProvider
    private var storage: Set<AnyCancellable> = []

    private let gracePeriod: TimeInterval
    /// The date written in the session events
    private let now: @Sendable () -> Date
    /// The time that measures the grace period. It keeps counting while the device sleeps (the app is suspended
    /// then, and comes back hours later with its timer still pending), and a change of the device's date does not
    /// move it.
    private let continuousTime: @Sendable () -> TimeInterval

    /// The app state changes and the grace period ends on the main thread (`TrackingRepository` expects its
    /// sessions to change there), but `stop()` is called from wherever the SDK is torn down.
    private let lock = NSLock()
    /// The trip to the background whose grace period is running. Only accessed with `lock` held.
    private var pendingBackground: PendingBackground?

    /// Its mutable properties are only accessed with `lock` held.
    private final class PendingBackground: @unchecked Sendable {
        let continuousTime: TimeInterval
        var timer: DispatchSourceTimer?
        var backgroundTask: BackgroundTask?

        init(continuousTime: TimeInterval) {
            self.continuousTime = continuousTime
        }
    }

    init(injector: Injector, gracePeriod: TimeInterval = 10, now: @escaping @Sendable () -> Date = Date.init,
         continuousTime: @escaping @Sendable () -> TimeInterval = AppSessionMonitor.continuousTime) {
        trackingRepository = injector.getInjected(identifiedBy: Injected.trackingRepository)
        appStateMonitor = injector.getInjected(identifiedBy: Injected.appStateMonitor)
        backgroundTaskProvider = injector.getInjected(identifiedBy: Injected.backgroundTaskProvider)
        self.gracePeriod = gracePeriod
        self.now = now
        self.continuousTime = continuousTime
    }

    func start() {
        appStateMonitor.appStatePublisher
            .removeDuplicates()
            .sink { [unowned self] appState in
                switch appState {
                case .background:
                    appMovedToBackground()
                case .active:
                    appMovedToForeground()
                case .none:
                    break
                }
            }.store(in: &storage)
    }

    func stop() {
        storage = []
        lock.lock()
        defer { lock.unlock() }
        // a session paused by a pending background ends at the date the app moved to background
        trackingRepository.appSessionEnded()
        if let pendingBackground {
            finish(pendingBackground)
        }
    }

    private func appMovedToBackground() {
        lock.lock()
        defer { lock.unlock() }
        guard pendingBackground == nil else { return }
        let background = PendingBackground(continuousTime: continuousTime())
        // no app session to keep: the SDK started while the app was in the background
        guard trackingRepository.appSessionPaused(at: now()) else { return }
        pendingBackground = background

        // Without a background task, iOS suspends the app a few seconds after it moved to background and the
        // session would only end when the app comes back, or at the next launch if it is killed meanwhile.
        background.backgroundTask = backgroundTaskProvider.beginTask { [weak self] in
            self?.gracePeriodEnded(for: background)
        }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + gracePeriod)
        timer.setEventHandler { [weak self] in self?.gracePeriodEnded(for: background) }
        background.timer = timer
        timer.activate()
    }

    private func appMovedToForeground() {
        lock.lock()
        defer { lock.unlock() }
        if let background = pendingBackground {
            defer { finish(background) }
            if continuousTime() - background.continuousTime < gracePeriod, trackingRepository.appSessionResumed() {
                return
            }
            trackingRepository.appSessionEnded()
        }
        trackingRepository.appSessionStarted()
    }

    private func gracePeriodEnded(for background: PendingBackground) {
        lock.lock()
        defer { lock.unlock() }
        // the app may have come back, or the SDK been stopped, between the moment this has been queued and now
        guard pendingBackground === background else { return }
        trackingRepository.appSessionEnded()
        finish(background)
    }

    /// Called once the session is resumed or ended: the app can be suspended from then on.
    /// - Important: `lock` must be held by the caller.
    private func finish(_ background: PendingBackground) {
        background.timer?.cancel()
        background.timer = nil
        if let backgroundTask = background.backgroundTask {
            backgroundTaskProvider.endTask(backgroundTask)
            background.backgroundTask = nil
        }
        if pendingBackground === background {
            pendingBackground = nil
        }
    }

    /// Seconds elapsed since an arbitrary point, including the time the device slept.
    static func continuousTime() -> TimeInterval {
        TimeInterval(clock_gettime_nsec_np(CLOCK_MONOTONIC)) / 1_000_000_000
    }
}
