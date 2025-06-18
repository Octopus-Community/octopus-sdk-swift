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

    private var timer: Timer?

    private let firstSessionHasBeenRecordedKey: String

    init(kind: SessionKind) {
        self.kind = kind
        currentSessionStore = SessionStore(prefix: "\(kind.storePrefix).current")
        previousSessionStore = SessionStore(prefix: "\(kind.storePrefix).previous")
        firstSessionHasBeenRecordedKey = "\(kind.storePrefix).firstSessionHasBeenRecordedKey"

        currentSessionStore.$session.sink { [unowned self] in
            currentSession = Session(from: $0)
        }.store(in: &storage)

        previousSessionStore.$session.sink { [unowned self] in
            previousSession = CompleteSession(from: $0)
        }.store(in: &storage)

        // if there is a current session during initialization, it means that it is an ended session
        if currentSession != nil {
            sessionEnded(useLastHeartbeatAsEndDate: true)
        }
    }

    func sessionStarted() {
        // if there is a current session, end it
        if currentSession != nil {
            sessionEnded()
        }

        let isFirstSession = !UserDefaults.standard.bool(forKey: firstSessionHasBeenRecordedKey)
        currentSessionStore.store(session: StorableSession(
            uuid: UUID().uuidString,
            startTimestamp: Date().timeIntervalSince1970,
            firstSession: isFirstSession,
            lastKnownTimestamp: Date().timeIntervalSince1970
        ))

        if isFirstSession {
            UserDefaults.standard.set(true, forKey: firstSessionHasBeenRecordedKey)
        }

        timer?.invalidate()
        timer = nil
        // start the timer
        timer = Timer.scheduledTimer(withTimeInterval: .minutes(1), repeats: true) { [weak self] timer in
            guard var currentSession = self?.currentSession else { return }
            currentSession.lastHeartbeatDate = Date()
            self?.currentSessionStore.store(session: currentSession.storableValue)
        }
    }

    func sessionEnded() {
        sessionEnded(useLastHeartbeatAsEndDate: false)
    }

    func clearPreviousSession() {
        previousSessionStore.store(session: nil)
    }
    
    /// Set the current session as completed
    /// - Parameter useLastHeartbeatAsEndDate: whether to use the last hearbeat of the current session as end date.
    ///      If false, the current date will be used.
    private func sessionEnded(useLastHeartbeatAsEndDate: Bool) {
        guard let currentSession else { return }
        timer?.invalidate()
        timer = nil
        let previousSession = currentSession.complete(useLastHeartbeatAsEndDate: useLastHeartbeatAsEndDate)
        previousSessionStore.store(session: previousSession.storableValue)
        currentSessionStore.store(session: nil)
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
