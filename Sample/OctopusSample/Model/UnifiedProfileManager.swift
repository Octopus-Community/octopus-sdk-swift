//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
@_spi(OctopusInternalTesting) import Octopus

/// The two Unified Profile inputs the host app controls. The SDK opens the app's profile on a profile tap only
/// when the community exposes client user ids AND the app wired `onNavigateToProfileCallback`.
///
/// Pure, so the Config line and the switch are unit-tested without an SDK.
struct UnifiedProfileHostState: Equatable {
    /// Local override of the community's `exposeClientUserId` flag. `nil` keeps the backend value.
    var exposeClientUserIdOverride: Bool?
    /// Whether the app wired `onNavigateToProfileCallback`.
    var profileCallbackWired: Bool

    /// The state the Config switch sets. On forces the flag on and wires the callback. Off clears the override
    /// (back to the backend value, as on Android) and unwires the callback, which alone turns the feature off.
    static func switched(_ isOn: Bool) -> UnifiedProfileHostState {
        isOn
            ? UnifiedProfileHostState(exposeClientUserIdOverride: true, profileCallbackWired: true)
            : UnifiedProfileHostState(exposeClientUserIdOverride: nil, profileCallbackWired: false)
    }

    /// Whether the switch reads as on: both inputs are set by the app, whatever the backend says.
    var isSwitchOn: Bool { exposeClientUserIdOverride == true && profileCallbackWired }

    /// What a profile tap does with this state, for the Config line. Built from the live state, so it also
    /// describes what the Unified Profile scenario's finer controls left behind.
    var statusLine: String {
        guard profileCallbackWired else {
            return "Off: profile taps open the Octopus profile (profile callback not wired)."
        }
        switch exposeClientUserIdOverride {
        case true?:
            return "On: profile taps open the app's profile, or the member's Octopus posts when they have no app " +
                "account."
        case false?:
            return "Off: profile taps open the Octopus profile (community flag forced off)."
        case nil:
            return "Set by the community: the profile callback is wired, the backend flag decides."
        }
    }
}

/// Owns the Unified Profile state the sample applies to the SDK, shared by the Config switch and the Unified
/// Profile scenario.
///
/// Only the switch is persisted. The scenario's "Backend flag override" controls are transient: they stay applied
/// until the SDK restarts, which goes back to what the switch says (as on Android). Applied again on every SDK
/// instance and after a community switch, which rebuilds the SDK core and drops its debug overrides.
@MainActor
final class UnifiedProfileManager: ObservableObject {
    static let instance = UnifiedProfileManager()

    nonisolated static let storageKey = "OctopusSample.unifiedProfile.enabled"

    /// The state applied to the SDK right now.
    @Published private(set) var state: UnifiedProfileHostState

    /// The persisted switch. Off by default, like the Android sample: a fresh install keeps the native profile.
    var isEnabled: Bool { defaults.bool(forKey: Self.storageKey) }

    private let defaults: UserDefaults
    private let wireProfileCallback: (Bool) -> Void
    private weak var octopus: OctopusSDK?

    /// Internal so tests can use an isolated store and observe the wiring; the app uses `instance`.
    init(defaults: UserDefaults = .standard,
         wireProfileCallback: @escaping (Bool) -> Void = { ClientProfileManager.instance.setCallbackWired($0) }) {
        self.defaults = defaults
        self.wireProfileCallback = wireProfileCallback
        state = .switched(defaults.bool(forKey: Self.storageKey))
    }

    /// Called for every SDK instance and after a community switch: applies the persisted switch to it, so a
    /// restart drops what the scenario's finer controls left behind (as on Android).
    func set(octopus: OctopusSDK) {
        self.octopus = octopus
        restorePersistedState()
    }

    /// The Config switch: sets both inputs, persists the choice and applies it at once. Works before the SDK
    /// exists; the state is then applied when it is created.
    func setEnabled(_ isOn: Bool) {
        defaults.set(isOn, forKey: Self.storageKey)
        state = .switched(isOn)
        apply()
    }

    /// Scenario control: overrides the community flag only, until `restorePersistedState()`.
    func setExposeClientUserIdOverride(_ value: Bool?) {
        state.exposeClientUserIdOverride = value
        apply()
    }

    /// Scenario control: wires or unwires the profile callback only, until `restorePersistedState()`.
    func setProfileCallbackWired(_ wired: Bool) {
        state.profileCallbackWired = wired
        apply()
    }

    /// Drops the scenario's transient changes and goes back to what the switch says.
    func restorePersistedState() {
        state = .switched(isEnabled)
        apply()
    }

    private func apply() {
        octopus?.debugOverrideExposeClientUserId(state.exposeClientUserIdOverride)
        wireProfileCallback(state.profileCallbackWired)
    }
}
