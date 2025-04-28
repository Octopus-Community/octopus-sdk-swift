//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import OctopusRemoteClient
import OctopusDependencyInjection
import OctopusGrpcModels
import os

extension Injected {
    static let trackingEventsSendingMonitor = Injector.InjectedIdentifier<TrackingEventsSendingMonitor>()
}

/// Monitors that observes tracking events in database and send them to the backend.
/// It groups the events in batch (2 seconds), and send them. It has a retry policy that retries after a exponential
/// duration. The monitor tries to send the event max 5 times, after that, it will delete the event. On the last
/// attempt, it will send the event individually, just in case other events of the batch were the source of the failure.
final class TrackingEventsSendingMonitor: InjectableObject, @unchecked Sendable {
    static let injectedIdentifier = Injected.trackingEventsSendingMonitor

    private let database: EventsDatabase
    private let remoteClient: OctopusRemoteClient
    private let authCallProvider: AuthenticatedCallProvider
    private let networkMonitor: NetworkMonitor
    private var storage: Set<AnyCancellable> = []

    /// Max attempts at sending an event before deleting it
    private let maxSendingAttempts: Int16 = 5
    /// Failing attempts in a row. Used to delay the next attempt.
    private var nbFailingAttempts = 0

    @Published private var isSendingEvents: Bool = false

    init(injector: Injector) {
        database = injector.getInjected(identifiedBy: Injected.eventsDatabase)
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        authCallProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)
        networkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor)
    }

    func start() {
        Publishers.CombineLatest(
            networkMonitor.connectionAvailablePublisher,
            $isSendingEvents
        ).map { [unowned self] isConnected, isSendingEvents in
            guard !isSendingEvents, isConnected else {
                return Just<[Event]>([]).eraseToAnyPublisher()
            }
            return database.eventsPublisher()
                .replaceError(with: [])
                .debounce(for: .seconds(2), scheduler: RunLoop.main)
                .eraseToAnyPublisher()
        }
        .switchToLatest()
        .sink { [unowned self] events in
            guard !events.isEmpty else { return }
            send(events: events)
        }.store(in: &storage)
    }

    func stop() {
        storage = []
    }
    
    /// Send events in batch and individually for the ones that have a sending attempt equal to the max.
    private func send(events: [Event]) {
        guard !events.isEmpty else { return }
        isSendingEvents = true

        // prepare the arrays of events: the ones that will be sent in batch and the ones that are expiring (i.e.
        // sending attempts > threshold)
        var eventsToBatch: [Event] = []
        var expiringEvents: [Event] = []
        for event in events {
            if event.sendingAttempts < maxSendingAttempts {
                eventsToBatch.append(event)
            } else {
                expiringEvents.append(event)
            }
        }

        let eventsToBatchIds = eventsToBatch.map { $0.uuid }

        Task {
            do {
                // first, try send all the expiring events
                try await sendExpiringEvents(events: expiringEvents)

                if !eventsToBatch.isEmpty {
                    // Then send the events in batch
                    if #available(iOS 14, *) { Logger.tracking.trace("Will send events: \(eventsToBatch)") }
                    _ = try await remoteClient.trackingService.track(
                        events: eventsToBatch.map { $0.toProto },
                        authenticationMethod: authCallProvider.authenticatedIfPossibleMethod())
                    if #available(iOS 14, *) { Logger.tracking.trace("Will delete events from db") }
                    try await database.deleteAll(ids: eventsToBatchIds)
                    nbFailingAttempts = 0
                }
            } catch {
                if #available(iOS 14, *) { Logger.tracking.trace("Error while sending events, will increment sending attempts and retry later: \(error)") }
                try? await database.incrementSendingAttempts(ids: eventsToBatchIds)
                // in case of error, wait before attempting a new time to send events according to `nbFailingAttempts`
                let waitingTime = getWaitingTime(for: nbFailingAttempts)
                if #available(iOS 14, *) { Logger.tracking.trace("Waiting for \(waitingTime) seconds before observing events again") }
                try await Task.sleep(nanoseconds: UInt64(waitingTime * 1_000_000_000))
                nbFailingAttempts += 1
            }
            isSendingEvents = false
        }
    }

    private func sendExpiringEvents(events: [Event]) async throws {
        guard !events.isEmpty else { return }
        if #available(iOS 14, *) { Logger.tracking.trace("Will send expiring events \(events.map(\.uuid))") }
        var lastError: Error?
        for event in events {
            if #available(iOS 14, *) { Logger.tracking.trace("Will send expiring event: \(event)") }
            do {
                _ = try await remoteClient.trackingService.track(
                    events: [event.toProto],
                    authenticationMethod: authCallProvider.authenticatedIfPossibleMethod())
            } catch {
                if #available(iOS 14, *) { Logger.tracking.trace("Error while sending event \(event): \(error)") }
                lastError = error
            }
            do {
                if #available(iOS 14, *) { Logger.tracking.trace("Deleting event \(event.uuid)") }
                try await database.deleteAll(ids: [event.uuid])
            } catch {
                if #available(iOS 14, *) { Logger.tracking.trace("Error while deleting event \(event): \(error)") }
                lastError = error
            }
        }
        if let lastError {
            throw lastError
        }
    }
    
    /// Get the waiting time according to the number of failing attempts.
    /// The first time (`nbFailingAttempts` = 0), it will retry immediatly.
    private func getWaitingTime(for nbFailingAttempts: Int) -> TimeInterval {
        switch nbFailingAttempts {
        case 0: 0
        case 1: 10
        case 2: 30
        case 3: 60
        case 4: 120
        case 5: 240
        default: 300
        }
    }
}

private extension Event {
    var toProto: Com_Octopuscommunity_TrackRequest.Event {
        Com_Octopuscommunity_TrackRequest.Event.with {
            $0.timestamp = date.timestampMs
            if let appSessionId {
                $0.appSessionID = appSessionId
            }
            if let uiSessionId {
                $0.octoSessionID = uiSessionId
            }

            $0.eventType = switch content {
            case let .enteringApp(firstSession):
                    .enteringApp(.with {
                        $0.firstSession = firstSession
                    })
            case let .leavingApp(startDate, endDate, firstSession):
                    .leavingApp(.with {
                        $0.sessionSummary = .with {
                            $0.startedAt = startDate.timestampMs
                            $0.endedAt = endDate.timestampMs
                            $0.duration = $0.endedAt - $0.startedAt
                            $0.firstSession = firstSession
                        }
                    })
            case let .enteringUI(firstSession):
                    .enteringOctopus(.with {
                        $0.firstSession = firstSession
                    })
            case let .leavingUI(startDate, endDate, firstSession):
                    .leavingOctopus(.with {
                        $0.sessionSummary = .with {
                            $0.startedAt = startDate.timestampMs
                            $0.endedAt = endDate.timestampMs
                            $0.duration = $0.endedAt - $0.startedAt
                            $0.firstSession = firstSession
                        }
                    })
            }
        }
    }
}
