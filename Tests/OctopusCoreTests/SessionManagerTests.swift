//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import XCTest
import Combine
@testable import OctopusCore

/// Sessions are started and ended from different threads: they start from the app lifecycle notifications
/// (main thread) and they end wherever the caller happens to be — `switchCommunity` ends them from a
/// background task. The manager must survive that.
class SessionManagerTests: XCTestCase {

    private var userDefaults: UserDefaults!
    private var suiteName: String!
    private var storage = [AnyCancellable]()

    override func setUp() {
        super.setUp()
        suiteName = "OctopusSdkTests.SessionManager.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        storage = []
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        super.tearDown()
    }

    /// A `Timer` only fires on the run loop of the thread that scheduled it, and the threads the SDK ends up
    /// on have no run loop running: a session started from one of them would never beat again.
    func testHeartbeatBeatsWhenTheSessionIsStartedOffTheMainThread() {
        let manager = SessionManager(kind: .app, heartbeatInterval: 0.05, userDefaults: userDefaults)

        let started = expectation(description: "session started off the main thread")
        DispatchQueue.global().async {
            manager.sessionStarted()
            started.fulfill()
        }
        wait(for: [started], timeout: 1)

        guard let firstBeat = manager.currentSession?.lastHeartbeatDate else {
            XCTFail("The session should have been started")
            return
        }
        let beaten = expectation(description: "heartbeat updated the current session")
        beaten.assertForOverFulfill = false
        manager.$currentSession
            .sink { session in
                guard let session, session.lastHeartbeatDate > firstBeat else { return }
                beaten.fulfill()
            }
            .store(in: &storage)

        wait(for: [beaten], timeout: 2)
    }

    /// Two threads ending the same session used to both get past the `currentSession` check: they raced on
    /// the heartbeat timer (crashing in `CFRunLoopTimerInvalidate`) and completed the session twice, which
    /// sends two `leavingApp` events for one session.
    func testConcurrentEndsCompleteTheSessionOnlyOnce() {
        let manager = SessionManager(kind: .app, userDefaults: userDefaults)
        let completedSessions = Collector<CompleteSession>()
        manager.$previousSession
            .compactMap { $0 }
            .sink { completedSessions.append($0) }
            .store(in: &storage)

        manager.sessionStarted()
        XCTAssertNotNil(manager.currentSession)

        let group = DispatchGroup()
        for _ in 0..<8 {
            DispatchQueue.global().async(group: group) { manager.sessionEnded() }
        }
        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)

        XCTAssertNil(manager.currentSession)
        XCTAssertEqual(completedSessions.values.count, 1)
    }

    /// Same race on the other entry point: restarting a session cancels the previous heartbeat timer.
    func testConcurrentStartsAndEndsKeepTheSessionConsistent() {
        let manager = SessionManager(kind: .octopusUI, heartbeatInterval: 0.01, userDefaults: userDefaults)

        let group = DispatchGroup()
        for index in 0..<40 {
            DispatchQueue.global().async(group: group) {
                if index.isMultiple(of: 2) { manager.sessionStarted() } else { manager.sessionEnded() }
            }
        }
        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)

        manager.sessionEnded()
        XCTAssertNil(manager.currentSession)
    }
}

/// Thread-safe accumulator: the values under test arrive from several threads at once.
private class Collector<T> {
    private let lock = NSLock()
    private var stored = [T]()

    var values: [T] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func append(_ value: T) {
        lock.lock()
        defer { lock.unlock() }
        stored.append(value)
    }
}
