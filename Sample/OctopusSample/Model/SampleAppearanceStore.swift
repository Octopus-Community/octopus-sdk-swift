//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import UIKit

/// Light or dark, for the whole app: the sample's own screens and the SDK screens it hosts.
enum SampleAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let defaultValue = SampleAppearance.system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// How Settings summarises it, as the Android sample does: "Follow system" rather than the bare segment label.
    var summaryTitle: String { self == .system ? "Follow system" : title }

    /// The window style it maps to. `.unspecified` hands the choice back to the device setting.
    var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// The theme the sample hands to the SDK. It only changes the Octopus screens: the sample's own screens keep the
/// sample palette whatever the preset.
enum SDKThemePreset: String, CaseIterable, Identifiable {
    /// The sample's own brand theme, built from its tokens, so the community and the host screens read as one
    /// app. The default, as on Android: the SDK's built-in primary reads as "unthemed", not as a choice.
    case octopusNavy = "navy"
    /// No theme handed to the SDK at all: what a fresh integration looks like.
    case sdkDefault = "sdk-default"

    static let defaultValue = SDKThemePreset.octopusNavy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .octopusNavy: return "Octopus navy"
        case .sdkDefault: return "SDK default"
        }
    }
}

/// Persists Settings › Appearance. Both choices apply at once, without a restart: the appearance through the
/// windows' `overrideUserInterfaceStyle` (which also reaches sheets and full screen covers), the preset through
/// the `octopusTheme` environment of the community screens.
final class SampleAppearanceStore: ObservableObject {
    static let instance = SampleAppearanceStore()

    static let appearanceKey = "OctopusSample.appearance.mode"
    static let themePresetKey = "OctopusSample.appearance.themePreset"

    @Published private(set) var appearance: SampleAppearance
    @Published private(set) var themePreset: SDKThemePreset

    private let defaults: UserDefaults

    /// Internal so tests can use an isolated store; the app uses `instance`.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = defaults.string(forKey: Self.appearanceKey)
            .flatMap(SampleAppearance.init(rawValue:)) ?? .defaultValue
        themePreset = defaults.string(forKey: Self.themePresetKey)
            .flatMap(SDKThemePreset.init(rawValue:)) ?? .defaultValue
    }

    func set(appearance: SampleAppearance) {
        defaults.set(appearance.rawValue, forKey: Self.appearanceKey)
        self.appearance = appearance
    }

    func set(themePreset: SDKThemePreset) {
        defaults.set(themePreset.rawValue, forKey: Self.themePresetKey)
        self.themePreset = themePreset
    }

    /// Back to the defaults, for Settings › Reset configuration.
    func reset() {
        defaults.removeObject(forKey: Self.appearanceKey)
        defaults.removeObject(forKey: Self.themePresetKey)
        appearance = .defaultValue
        themePreset = .defaultValue
    }
}
