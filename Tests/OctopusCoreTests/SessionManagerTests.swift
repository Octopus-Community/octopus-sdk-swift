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

    /// A session paused when the app goes to the background and ended once the grace period is over ends when
    /// the app went to the background: the grace period is not session time.
    func testPausedSessionEndsAtThePauseDate() throws {
        let manager = SessionManager(kind: .app, userDefaults: userDefaults)
        manager.sessionStarted()
        let pauseDate = Date().addingTimeInterval(-5)

        manager.sessionPaused(at: pauseDate)
        XCTAssertTrue(manager.isPaused)
        manager.sessionEnded()

        XCTAssertNil(manager.currentSession)
        XCTAssertFalse(manager.isPaused)
        XCTAssertEqual(try XCTUnwrap(manager.previousSession).endDate.timeIntervalSince1970,
                       pauseDate.timeIntervalSince1970, accuracy: 0.001)
    }

    /// The app can be killed while it is in the background, during the grace period: the next launch completes
    /// the session when the app went to the background, not at its last beat before that.
    func testPausedSessionIsRecoveredAtThePauseDateAfterTheAppIsKilled() throws {
        let manager = SessionManager(kind: .app, userDefaults: userDefaults)
        manager.sessionStarted()
        let pauseDate = Date().addingTimeInterval(-5)
        manager.sessionPaused(at: pauseDate)

        let nextLaunchManager = SessionManager(kind: .app, userDefaults: userDefaults)

        XCTAssertNil(nextLaunchManager.currentSession)
        XCTAssertEqual(try XCTUnwrap(nextLaunchManager.previousSession).endDate.timeIntervalSince1970,
                       pauseDate.timeIntervalSince1970, accuracy: 0.001)
    }

    /// A beat during the grace period would move the recovered end date past the moment the app went to the
    /// background.
    func testPausedSessionDoesNotBeat() async throws {
        let manager = SessionManager(kind: .app, heartbeatInterval: 0.02, userDefaults: userDefaults)
        manager.sessionStarted()
        let pauseDate = Date()
        manager.sessionPaused(at: pauseDate)

        try await Task.sleep(nanoseconds: .secondsToNano(0.2))

        XCTAssertEqual(try XCTUnwrap(manager.currentSession?.lastHeartbeatDate).timeIntervalSince1970,
                       pauseDate.timeIntervalSince1970, accuracy: 0.001)
    }

    /// Coming back within the grace period keeps the same session, alive again from now on.
    func testResumedSessionKeepsItsIdAndBeatsAgain() async throws {
        let manager = SessionManager(kind: .app, heartbeatInterval: 0.02, userDefaults: userDefaults)
        manager.sessionStarted()
        let sessionId = try XCTUnwrap(manager.currentSession?.uuid)
        let pauseDate = Date().addingTimeInterval(-5)
        manager.sessionPaused(at: pauseDate)
        XCTAssertTrue(manager.isPaused)

        manager.sessionResumed()

        XCTAssertFalse(manager.isPaused)
        XCTAssertEqual(manager.currentSession?.uuid, sessionId)
        let resumeBeat = try XCTUnwrap(manager.currentSession?.lastHeartbeatDate)
        XCTAssertGreaterThan(resumeBeat, pauseDate)
        // the heartbeat goes on after the beat of the resume
        try await assertWithTimeout((manager.currentSession?.lastHeartbeatDate ?? .distantPast) > resumeBeat)
        manager.sessionEnded()
        XCTAssertGreaterThan(try XCTUnwrap(manager.previousSession).endDate, pauseDate)
    }

    /// Pausing or resuming without a session does nothing: no session is created.
    func testPauseAndResumeWithoutSessionDoNothing() {
        let manager = SessionManager(kind: .octopusUI, userDefaults: userDefaults)

        manager.sessionPaused(at: Date())
        XCTAssertFalse(manager.isPaused)
        manager.sessionResumed()

        XCTAssertNil(manager.currentSession)
        XCTAssertNil(manager.previousSession)
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
