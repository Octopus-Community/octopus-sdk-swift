//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine

/// A manager for a kind of session
/// In charge of loading and saving the session, moving a current session to a completed session and keeping heartbeat
/// for the current session.
class SessionManager: @unchecked Sendable {

    @Published private(set) var currentSession: Session?
    @Published private(set) var previousSession: CompleteSession?

    private let currentSessionStore: SessionStore
    private let previousSessionStore: SessionStore
    private var storage = [AnyCancellable]()

    private let kind: SessionKind

    /// Serializes the changes of the session.
    ///
    /// Sessions start on the main thread (they follow the app lifecycle notifications) but they end wherever
    /// the caller is: `switchCommunity` ends them from a background task, and the app can be backgrounded
    /// while it runs. Two threads ending the same session both got past the `currentSession` check of
    /// `endCurrentSession`: the session was completed twice (hence two `leavingApp` events for one session)
    /// and both of them released the heartbeat timer, which crashed in `CFRunLoopTimerInvalidate`.
    ///
    /// Only the changes take it, not the reads of `currentSession`/`previousSession`: a read is a plain
    /// `@Published` access, so reading one costs nothing and cannot be blocked by a session being written on
    /// another thread. Recursive because a change notifies its subscribers synchronously, from inside the
    /// locked section: a subscriber that ends up calling back here must not deadlock.
    private let lock = NSRecursiveLock()

    private var timer: DispatchSourceTimer?

    private let firstSessionHasBeenRecordedKey: String
    private let userDefaults: UserDefaults
    private let heartbeatInterval: TimeInterval
    /// Beats are not run on the main queue: they take `lock`, and the main thread should not have to wait
    /// behind a session being ended on another thread (which holds `lock` while writing the user defaults).
    private let heartbeatQueue = DispatchQueue(label: "Octopus.SessionManager.heartbeat")

    init(kind: SessionKind, forceReset: Bool = false, heartbeatInterval: TimeInterval = .minutes(1),
         userDefaults: UserDefaults = .standard) {
        self.kind = kind
        self.heartbeatInterval = heartbeatInterval
        self.userDefaults = userDefaults
        currentSessionStore = SessionStore(prefix: "\(kind.storePrefix).current", userDefaults: userDefaults)
        previousSessionStore = SessionStore(prefix: "\(kind.storePrefix).previous", userDefaults: userDefaults)
        firstSessionHasBeenRecordedKey = "OctopusSDK.tracking.\(kind.storePrefix).firstSessionHasBeenRecordedKey"

        migrateUserDefaultsIfNeeded()

        if forceReset {
            userDefaults.set(false, forKey: firstSessionHasBeenRecordedKey)
        }

        currentSessionStore.$session.sink { [unowned self] in
            currentSession = Session(from: $0)
        }.store(in: &storage)

        previousSessionStore.$session.sink { [unowned self] in
            previousSession = CompleteSession(from: $0)
        }.store(in: &storage)

        // if there is a current session during initialization, it means that it is an ended session
        if currentSession != nil {
            lock.lock()
            endCurrentSession(useLastHeartbeatAsEndDate: true)
            lock.unlock()
        }
    }

    deinit {
        timer?.cancel()
    }

    func sessionStarted() {
        lock.lock()
        defer { lock.unlock() }
        // if there is a current session, end it
        if currentSession != nil {
            endCurrentSession(useLastHeartbeatAsEndDate: false)
        }

        let isFirstSession = !userDefaults.bool(forKey: firstSessionHasBeenRecordedKey)
        currentSessionStore.store(session: StorableSession(
            uuid: UUID().uuidString,
            startTimestamp: Date().timeIntervalSince1970,
            firstSession: isFirstSession,
            lastKnownTimestamp: Date().timeIntervalSince1970
        ))

        if isFirstSession {
            userDefaults.set(true, forKey: firstSessionHasBeenRecordedKey)
        }

        startHeartbeat()
    }

    func sessionEnded() {
        lock.lock()
        defer { lock.unlock() }
        endCurrentSession(useLastHeartbeatAsEndDate: false)
    }

    func clearPreviousSession() {
        lock.lock()
        defer { lock.unlock() }
        previousSessionStore.store(session: nil)
    }

    /// Set the current session as completed
    /// - Parameter useLastHeartbeatAsEndDate: whether to use the last hearbeat of the current session as end date.
    ///      If false, the current date will be used.
    /// - Important: `lock` must be held by the caller.
    private func endCurrentSession(useLastHeartbeatAsEndDate: Bool) {
        guard let currentSession else { return }
        stopHeartbeat()
        let previousSession = currentSession.complete(useLastHeartbeatAsEndDate: useLastHeartbeatAsEndDate)
        previousSessionStore.store(session: previousSession.storableValue)
        currentSessionStore.store(session: nil)
    }

    /// Records that the session is still alive, so a session that is never ended properly (the app is killed
    /// or crashes) can be completed at its last beat.
    ///
    /// A dispatch timer and not a `Timer`: a `Timer` belongs to the run loop of the thread that scheduled it.
    /// It has to be invalidated from that same thread, and invalidating the main run loop's timer from a
    /// background task (as ending a session during a community switch does) corrupts the run loop. It also
    /// never fires at all when the session is started from a thread whose run loop is not running, which is
    /// the case of every thread but the main one here. A dispatch timer can be scheduled and cancelled from
    /// any thread.
    /// - Important: `lock` must be held by the caller.
    private func startHeartbeat() {
        stopHeartbeat()
        let timer = DispatchSource.makeTimerSource(queue: heartbeatQueue)
        timer.schedule(deadline: .now() + heartbeatInterval, repeating: heartbeatInterval)
        timer.setEventHandler { [weak self] in self?.beat() }
        self.timer = timer
        timer.activate()
    }

    /// - Important: `lock` must be held by the caller.
    private func stopHeartbeat() {
        timer?.cancel()
        timer = nil
    }

    private func beat() {
        lock.lock()
        defer { lock.unlock() }
        // the session can have ended between the moment this beat has been queued and now
        guard var session = currentSession else { return }
        session.lastHeartbeatDate = Date()
        currentSessionStore.store(session: session.storableValue)
    }

    /// This function is here because there was a bug up until the 1.9.3 where the prefix was missing the
    /// `OctopusSDK.tracking.`
    ///
    /// This function transfers the previous data to the new keys, containing the correct prefix.
    private func migrateUserDefaultsIfNeeded() {
        let oldFirstSessionHasBeenRecordedKey = firstSessionHasBeenRecordedKey
            .replacingOccurrences(of: "OctopusSDK.tracking.", with: "")

        guard let firstSessionHasBeenRecording = userDefaults.object(forKey: oldFirstSessionHasBeenRecordedKey) as? Bool
        else {
            return
        }

        userDefaults.set(firstSessionHasBeenRecording, forKey: firstSessionHasBeenRecordedKey)
        userDefaults.removeObject(forKey: oldFirstSessionHasBeenRecordedKey)
    }
}

private extension SessionKind {
    var storePrefix: String {
        switch self {
        case .app:
            return "appSession"
        case .octopusUI:
            return "octopusUISession"
        }
    }
}
