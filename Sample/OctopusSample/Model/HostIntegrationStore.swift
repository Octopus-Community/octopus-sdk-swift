//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// How the sample answers `onNavigateToURLCallback`, chosen in Settings › Host app integration.
enum HostURLPolicy: String, CaseIterable, Identifiable {
    /// The app opens its own contact link (and one redirected search link), Octopus opens every other link.
    case sampleRule = "default"
    /// Every link returns `.handledByApp`: the app opens it.
    case alwaysApp = "app"
    /// Every link returns `.handledByOctopus`: the SDK opens it.
    case alwaysOctopus = "octopus"

    static let defaultValue = HostURLPolicy.sampleRule

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sampleRule: return "Sample rule (default)"
        case .alwaysApp: return "Always open in the app"
        case .alwaysOctopus: return "Always let Octopus open"
        }
    }

    var summary: String {
        switch self {
        case .sampleRule: return "The app opens its own contact link, Octopus opens every other link."
        case .alwaysApp: return "Every link returns handledByApp; the app opens it."
        case .alwaysOctopus: return "Every link returns handledByOctopus; the SDK opens it."
        }
    }

    /// What the app does with a link the SDK is about to open. Pure, so the three policies are unit-tested.
    enum Decision: Equatable {
        /// The app opens this URL itself (it may differ from the tapped one) and the SDK does nothing more.
        case openInApp(URL)
        /// The SDK opens the link.
        case letOctopusOpen
    }

    func decision(for url: URL) -> Decision {
        switch self {
        case .alwaysOctopus:
            return .letOctopusOpen
        case .alwaysApp:
            return .openInApp(url)
        case .sampleRule:
            if url.host == "www.octopuscommunity.com" && url.path == "/contact" {
                return .openInApp(URL(string: "mailto:contact@octopuscommunity.com?subject=Contact")!)
            } else if url.host == "www.google.com" {
                return .openInApp(URL(string: "https://www.qwant.com/")!)
            }
            return .letOctopusOpen
        }
    }
}

/// Persists what the host app wires in Settings › Host app integration: the switchable callbacks and the URL
/// policy. Everything is on by default, like a complete integration.
///
/// The iOS SDK reads its callbacks when it needs them, so every change applies at once: the managers observe
/// this store and re-wire the live SDK instance (see `ClientProfileManager`, `GroupAccessDeniedManager` and
/// `URLManager`).
final class HostIntegrationStore: ObservableObject {
    static let instance = HostIntegrationStore()

    static let profileEditKey = "OctopusSample.hostIntegration.profileEdit"
    static let groupAccessDeniedKey = "OctopusSample.hostIntegration.groupAccessDenied"
    static let urlPolicyKey = "OctopusSample.hostIntegration.urlPolicy"

    /// Whether `onNavigateToProfileEditCallback` is wired. Unwired, the SDK hides "Edit my profile" in the
    /// connected user's Activity menu.
    @Published private(set) var isProfileEditWired: Bool
    /// Whether `groupAccessDeniedCallback` answers. Off, it is a no-op: the SDK has no fallback of its own, so a
    /// locked group tap then does nothing.
    @Published private(set) var isGroupAccessDeniedWired: Bool
    @Published private(set) var urlPolicy: HostURLPolicy

    private let defaults: UserDefaults

    /// Internal so tests can use an isolated store; the app uses `instance`.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isProfileEditWired = defaults.object(forKey: Self.profileEditKey) as? Bool ?? true
        isGroupAccessDeniedWired = defaults.object(forKey: Self.groupAccessDeniedKey) as? Bool ?? true
        urlPolicy = defaults.string(forKey: Self.urlPolicyKey)
            .flatMap(HostURLPolicy.init(rawValue:)) ?? .defaultValue
    }

    func setProfileEditWired(_ wired: Bool) {
        defaults.set(wired, forKey: Self.profileEditKey)
        isProfileEditWired = wired
    }

    func setGroupAccessDeniedWired(_ wired: Bool) {
        defaults.set(wired, forKey: Self.groupAccessDeniedKey)
        isGroupAccessDeniedWired = wired
    }

    func set(urlPolicy: HostURLPolicy) {
        defaults.set(urlPolicy.rawValue, forKey: Self.urlPolicyKey)
        self.urlPolicy = urlPolicy
    }

    /// Back to a complete integration, for Settings › Reset configuration.
    func reset() {
        [Self.profileEditKey, Self.groupAccessDeniedKey, Self.urlPolicyKey].forEach(defaults.removeObject(forKey:))
        isProfileEditWired = true
        isGroupAccessDeniedWired = true
        urlPolicy = .defaultValue
    }
}
