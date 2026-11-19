//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Testing
@testable import OctopusCore

/// The monitors that call the server run only while the community is open: they are stopped when it closes, and
/// started again, followed by what a launch would load, when it reopens.
struct CommunityClosureCoordinatorTests {
    private let closure = CommunityClosure(kind: .closed, message: "Closed msg", nextCheckDate: Date())

    /// Records the coordinator's actions, in order.
    private final class Journal: @unchecked Sendable {
        private let lock = NSLock()
        private var _entries = [String]()
        var entries: [String] {
            lock.lock()
            defer { lock.unlock() }
            return _entries
        }

        func append(_ entry: String) {
            lock.lock()
            defer { lock.unlock() }
            _entries.append(entry)
        }
    }

    @Test func anOpenLaunchStartsTheServerMonitors() {
        let subject = CurrentValueSubject<CommunityClosure?, Never>(nil)
        let journal = Journal()
        let coordinator = makeCoordinator(subject: subject, journal: journal)

        coordinator.start()

        #expect(journal.entries == ["start"])
    }

    @Test func aClosedLaunchStartsNoServerMonitor() async throws {
        let subject = CurrentValueSubject<CommunityClosure?, Never>(closure)
        let journal = Journal()
        let coordinator = makeCoordinator(subject: subject, journal: journal)

        coordinator.start()

        try await Task.sleep(nanoseconds: .secondsToNano(0.1))
        #expect(journal.entries.isEmpty)
    }

    @Test func closingStopsTheServerMonitors() async throws {
        let subject = CurrentValueSubject<CommunityClosure?, Never>(nil)
        let journal = Journal()
        let coordinator = makeCoordinator(subject: subject, journal: journal)
        coordinator.start()

        subject.send(closure)

        try await expectWithTimeout(journal.entries == ["start", "stop"])
    }

    @Test func reopeningResumesLikeALaunch() async throws {
        let subject = CurrentValueSubject<CommunityClosure?, Never>(closure)
        let journal = Journal()
        let coordinator = makeCoordinator(subject: subject, journal: journal)
        coordinator.start()

        subject.send(nil)

        try await expectWithTimeout(journal.entries == ["start", "resume"])
    }

    /// A closure extended by a check is still a closure: nothing to stop again.
    @Test func aStillClosedCheckChangesNothing() async throws {
        let subject = CurrentValueSubject<CommunityClosure?, Never>(closure)
        let journal = Journal()
        let coordinator = makeCoordinator(subject: subject, journal: journal)
        coordinator.start()

        subject.send(CommunityClosure(kind: .closed, message: "Closed msg",
                                      nextCheckDate: Date().addingTimeInterval(60)))

        try await Task.sleep(nanoseconds: .secondsToNano(0.1))
        #expect(journal.entries.isEmpty)
    }

    private func makeCoordinator(subject: CurrentValueSubject<CommunityClosure?, Never>, journal: Journal)
    -> CommunityClosureCoordinator {
        CommunityClosureCoordinator(
            closurePublisher: subject.eraseToAnyPublisher(),
            isClosed: { subject.value != nil },
            startServerMonitors: { journal.append("start") },
            stopServerMonitors: { journal.append("stop") },
            resume: { journal.append("resume") })
    }
}
