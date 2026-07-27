//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import OctopusDependencyInjection
import os

extension Injected {
    static let octopusDrivenLoginMonitor = Injector.InjectedIdentifier<OctopusDrivenLoginMonitor>()
}

/// The user action that triggered an Octopus login request.
///
/// Its `rawValue` is the cross-platform contract used as the `action_type` property of the
/// `octopus_driven_login` analytics event, so these values must stay in sync with the other SDKs
/// (they mirror the UI `UserAction` cases, and Android's `UserAction`).
public enum OctopusDrivenLoginAction: String, Sendable {
    case post
    case comment
    case reply
    case reaction
    case vote
    case moderation
    case blockUser
    case viewOwnProfile
}

/// Minimal seam for emitting the typed Octopus-driven-login tracking event, so
/// `OctopusDrivenLoginMonitor` can be unit-tested without building the full `TrackingRepository`
/// (and its CoreData/session dependencies).
protocol OctopusDrivenLoginTracker: AnyObject {
    func trackOctopusDrivenLogin(action: OctopusDrivenLoginAction)
}

extension TrackingRepository: OctopusDrivenLoginTracker {}

/// Detects "Octopus-driven logins" and emits the dedicated `octopus_driven_login` tracking event
/// (via the typed `TrackRequest.octopusDrivenLogin` proto field).
///
/// The SDK considers Octopus responsible for a login when, within the same app run, the user:
/// 1. triggered an action that required login (the login screen was presented — the UI calls
///    ``notifyLoginRequested(action:)`` from `ConnectedActionChecker`), **and**
/// 2. then becomes a real (non-guest) logged-in user — even if the login itself happens outside the
///    Octopus UI, in the host app's SSO flow.
///
/// The event carries the action type that triggered the login request (the most recent one).
///
/// State is kept in memory only, so it naturally resets on a cold app launch (a new app run). It is
/// deliberately **not** reset on background/foreground: the host SSO flow often bounces the app
/// through an external browser/app, and resetting on that transition would drop the very logins this
/// event is meant to attribute to Octopus.
public final class OctopusDrivenLoginMonitor: InjectableObject {
    public static let injectedIdentifier = Injected.octopusDrivenLoginMonitor

    private let connectionRepository: ConnectionRepository
    private let tracker: OctopusDrivenLoginTracker

    /// The action of the most recent login request not yet attributed to a login.
    private var pendingAction: OctopusDrivenLoginAction?
    /// Whether the user was already a real (non-guest) logged-in user on the previous observed state,
    /// so we only emit on the logged-out/guest → logged-in edge (not on every state republish).
    private var wasLoggedIn = false
    private var storage: Set<AnyCancellable> = []

    init(injector: Injector) {
        connectionRepository = injector.getInjected(identifiedBy: Injected.connectionRepository)
        tracker = injector.getInjected(identifiedBy: Injected.trackingRepository)
    }

    /// Direct-dependency initializer for unit tests.
    init(connectionRepository: ConnectionRepository, tracker: OctopusDrivenLoginTracker) {
        self.connectionRepository = connectionRepository
        self.tracker = tracker
    }

    /// Records that the login screen was presented because the user tried to perform `action`.
    /// Called from the UI at the moment login is actually required.
    public func notifyLoginRequested(action: OctopusDrivenLoginAction) {
        pendingAction = action
    }

    func start() {
        // Seed from the current state so a user who is already logged in at launch doesn't produce a
        // false edge on the publisher's initial replay.
        wasLoggedIn = Self.isLoggedIn(connectionRepository.connectionState)
        connectionRepository.connectionStatePublisher
            .sink { [weak self] state in
                self?.handle(state: state)
            }
            .store(in: &storage)
    }

    func stop() {
        storage = []
    }

    private func handle(state: ConnectionState) {
        let isLoggedIn = Self.isLoggedIn(state)
        defer { wasLoggedIn = isLoggedIn }
        // Only the logged-out/guest → logged-in edge counts, and only if a login was requested.
        guard !wasLoggedIn, isLoggedIn, let action = pendingAction else { return }
        pendingAction = nil
        tracker.trackOctopusDrivenLogin(action: action)
        if #available(iOS 14, *) {
            Logger.tracking.debug("Emitted octopus_driven_login event (action: \(action.rawValue))")
        }
    }

    private static func isLoggedIn(_ state: ConnectionState) -> Bool {
        guard let user = state.user else { return false }
        return !user.profile.isGuest
    }
}
