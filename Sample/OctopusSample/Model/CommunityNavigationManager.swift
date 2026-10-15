//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine

/// Where the Community tab shows the SDK screens, the same two values as the Android sample's
/// `SDKConfig.CommunityNavigation`.
enum CommunityNavigation: String, CaseIterable, Identifiable {
    /// `OctopusHomeScreen` and its navigation stack live inside the Community tab: the tab bar stays visible
    /// on every SDK screen.
    case inTab
    /// The SDK screens are presented above the tab bar, as an app without tabs would show them.
    case fullScreen

    /// A config saved before this setting existed has no value: it opens in the tab.
    static let defaultValue = CommunityNavigation.inTab

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inTab: return "In tab"
        case .fullScreen: return "Full screen"
        }
    }

    /// The value stored under `rawValue`, or the default when nothing (or an unknown value) is stored.
    static func stored(_ rawValue: String?) -> CommunityNavigation {
        rawValue.flatMap(CommunityNavigation.init(rawValue:)) ?? defaultValue
    }
}

/// Persists the tester's `CommunityNavigation` choice. It is a host-app integration setting, not part of the
/// SDK config: changing it never rebuilds the SDK, it only resets the Community tab.
final class CommunityNavigationManager: ObservableObject {
    static let instance = CommunityNavigationManager()

    static let storageKey = "sampleCommunityNavigation"

    @Published var mode: CommunityNavigation {
        didSet {
            guard mode != oldValue else { return }
            defaults.set(mode.rawValue, forKey: Self.storageKey)
        }
    }

    private let defaults: UserDefaults

    /// Internal so tests can read and write an isolated store; the app uses `instance`.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        mode = .stored(defaults.string(forKey: Self.storageKey))
    }
}
