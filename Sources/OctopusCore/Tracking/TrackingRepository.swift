//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import OctopusRemoteClient
import OctopusDependencyInjection
import os

extension Injected {
    static let trackingRepository = Injector.InjectedIdentifier<TrackingRepository>()
}

/// Repository in charge of getting and storing tracking events.
public class TrackingRepository: InjectableObject, @unchecked Sendable {
    public static let injectedIdentifier = Injected.trackingRepository

    private let database: EventsDatabase
    private let remoteClient: OctopusRemoteClient
    private let authCallProvider: AuthenticatedCallProvider
    private let octopusUISessionManager: SessionManager
    private let appSessionManager: SessionManager
    private var storage = [AnyCancellable]()

    /// Whether the Octopus UI is currently displayed. Used to end the UI session when the app session is ended
    private var octopusUIIsDisplayed = false

    init(injector: Injector) {
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        database = injector.getInjected(identifiedBy: Injected.eventsDatabase)
        authCallProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)

        octopusUISessionManager = SessionManager(kind: .octopusUI)
        appSessionManager = SessionManager(kind: .app)

        // listen to current UI session in order to create `enteringUI` event
        octopusUISessionManager.$currentSession
            .removeDuplicates(by: {$0?.uuid == $1?.uuid })
            .sink { [unowned self] in
                guard let session = $0 else { return }
                if #available(iOS 14, *) { Logger.tracking.trace("UI session started with uuid: \(session.uuid)") }
                // first, set the new session id to the remote client
                remoteClient.set(octopusUISessionId: session.uuid)
                triggerEnteringOctopusEvent(octoUISession: session)
            }.store(in: &storage)

        // listen to previous UI session in order to create `leavingUI` event
        octopusUISessionManager.$previousSession
            .sink { [unowned self] in
                guard let session = $0 else { return }
                if #available(iOS 14, *) { Logger.tracking.trace("UI session stopped with uuid: \(session.uuid)") }
                remoteClient.set(octopusUISessionId: nil)
                triggerLeavingOctopusEvent(octoUISession: session)
            }.store(in: &storage)

        // listen to current app session in order to create `enteringApp` event
        appSessionManager.$currentSession
            .removeDuplicates(by: { $0?.uuid == $1?.uuid })
            .sink { [unowned self] in
                guard let session = $0 else { return }
                if #available(iOS 14, *) { Logger.tracking.trace("App session started with uuid: \(session.uuid)") }
                // first, set the new session id to the remote client
                remoteClient.set(appSessionId: session.uuid)
                triggerEnteringAppEvent(appSession: session)
            }.store(in: &storage)

        // listen to previous app session in order to create `leavingApp` event
        appSessionManager.$previousSession
            .sink { [unowned self] in
                guard let session = $0 else { return }
                if #available(iOS 14, *) { Logger.tracking.trace("App session stopped with uuid: \(session.uuid)") }
                remoteClient.set(appSessionId: nil)
                triggerLeavingAppEvent(appSession: session)
            }.store(in: &storage)
    }
    
    /// Inform the SDK that the OctopusUI is displayed
    public func octopusUISessionStarted() {
        octopusUIIsDisplayed = true
        // only start an OctopusUI session if the app session is started
        if appSessionManager.currentSession != nil {
            octopusUISessionManager.sessionStarted()
        }
    }

    /// Inform the SDK that the OctopusUI is not displayed anymore
    public func octopusUISessionEnded() {
        octopusUIIsDisplayed = false
        octopusUISessionManager.sessionEnded()
    }

    public func set(hasAccessToCommunity: Bool) {
        remoteClient.set(hasAccessToCommunity: hasAccessToCommunity)
    }

    public func trackPostOpened(origin: PostOpenedOrigin, success: Bool) async throws {
        try await database.upsert(event: Event(
            date: Date(),
            appSessionId: appSessionManager.currentSession?.uuid,
            uiSessionId: octopusUISessionManager.currentSession?.uuid,
            content: .postOpened(origin: origin.internalValue, success: success)))
    }

    public func trackClientObjectOpenedFromBridge() async throws {
        try await database.upsert(event: Event(
            date: Date(),
            appSessionId: appSessionManager.currentSession?.uuid,
            uiSessionId: octopusUISessionManager.currentSession?.uuid,
            content: .openClientObjectFromBridge))
    }

    public func trackTranslationButtonHit(translationDisplayed: Bool) {
        Task {
            try await database.upsert(event: Event(
                date: Date(),
                appSessionId: appSessionManager.currentSession?.uuid,
                uiSessionId: octopusUISessionManager.currentSession?.uuid,
                content: .translationButtonHit(translationDisplayed: translationDisplayed)))
        }
    }

    public func track(customEvent: CustomEvent) async throws {
        try await database.upsert(event: Event(
            date: Date(),
            appSessionId: appSessionManager.currentSession?.uuid,
            uiSessionId: octopusUISessionManager.currentSession?.uuid,
            content: .custom(customEvent)))
    }

    func appSessionStarted() {
        appSessionManager.sessionStarted()
        if octopusUIIsDisplayed {
            octopusUISessionManager.sessionStarted()
        }
    }

    func appSessionEnded() {
        // if octopusUIIsDisplayed is true, consider the octopus UI session as ended
        // (but still remember octopusUIIsDisplayed to start a new UI session when app session is started again).
        if octopusUIIsDisplayed {
            octopusUISessionManager.sessionEnded()
        }
        appSessionManager.sessionEnded()
    }

    private func triggerEnteringAppEvent(appSession session: Session) {
        Task {
            do {
                try await database.upsert(
                    event: Event(
                        date: session.startDate,
                        appSessionId: session.uuid,
                        uiSessionId: octopusUISessionManager.currentSession?.uuid,
                        content: .enteringApp(firstSession: session.firstSession))
                )
            } catch {
                if #available(iOS 14, *) { Logger.tracking.trace("Error triggering entering app event: \(error)") }
            }
        }
    }

    private func triggerLeavingAppEvent(appSession session: CompleteSession) {
        Task {
            do {
                try await database.upsert(
                    event: Event(
                        date: session.endDate,
                        appSessionId: session.uuid,
                        uiSessionId: octopusUISessionManager.currentSession?.uuid,
                        content: .leavingApp(startDate: session.startDate, endDate: session.endDate,
                                             firstSession: session.firstSession))
                )
                appSessionManager.clearPreviousSession()
            } catch {
                if #available(iOS 14, *) { Logger.tracking.trace("Error triggering leaving app event: \(error)") }
            }
        }
    }

    private func triggerEnteringOctopusEvent(octoUISession session: Session) {
        Task {
            do {
                try await database.upsert(
                    event: Event(
                        date: session.startDate,
                        appSessionId: appSessionManager.currentSession?.uuid,
                        uiSessionId: session.uuid,
                        content: .enteringUI(firstSession: session.firstSession))
                )
            } catch {
                if #available(iOS 14, *) { Logger.tracking.debug("Error triggering entering UI event: \(error)") }
            }
        }
    }

    private func triggerLeavingOctopusEvent(octoUISession session: CompleteSession) {
        Task {
            do {
                try await database.upsert(
                    event: Event(
                        date: session.endDate,
                        appSessionId: appSessionManager.currentSession?.uuid,
                        uiSessionId: session.uuid,
                        content: .leavingUI(startDate: session.startDate, endDate: session.endDate,
                                            firstSession: session.firstSession))
                )
                octopusUISessionManager.clearPreviousSession()
            } catch {
                if #available(iOS 14, *) { Logger.tracking.trace("Error triggering leaving UI event: \(error)") }
            }
        }
    }
}
