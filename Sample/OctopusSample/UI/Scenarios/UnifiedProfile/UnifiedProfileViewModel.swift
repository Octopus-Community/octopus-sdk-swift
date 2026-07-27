//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
@_spi(OctopusInternalTesting) import Octopus

/// View model of UnifiedProfileView.
///
/// Applies a DEBUG-only override of the `CommunityConfig.exposeClientUserId` activation flag
/// (Unified Profile, OCT-1374), so the feature can be exercised in the sample before the backend
/// serves the flag. Unified Profile is active only when this flag is on **and**
/// `onNavigateToProfileCallback` is wired — the sample always wires the callback by default via
/// `ClientProfileManager`.
@MainActor
class UnifiedProfileViewModel: ObservableObject {
    enum Mode: Int, CaseIterable, Identifiable {
        case backend = 0
        case forceActive = 1
        case forceInactive = 2

        var id: Int { rawValue }

        var label: String {
            switch self {
            case .backend: "Use backend value"
            case .forceActive: "Force active"
            case .forceInactive: "Force inactive"
            }
        }

        var testId: String { "qa-preset-unifiedProfile-\(rawValue)" }

        var overrideValue: Bool? {
            switch self {
            case .backend: nil
            case .forceActive: true
            case .forceInactive: false
            }
        }
    }

    @Published private(set) var appliedMode: Mode = .backend

    /// Whether the host wired `onNavigateToProfileCallback` — the second input of the Unified
    /// Profile AND-gate. Backed by `ClientProfileManager`; wired by default.
    @Published var callbackWired: Bool = ClientProfileManager.instance.isCallbackWired

    /// Whether the host wired `onNavigateToProfileEditCallback` — gates the "Edit my profile" item of
    /// the connected-user Activity screen's top-right menu. Backed by `ClientProfileManager`; wired
    /// by default.
    @Published var editCallbackWired: Bool = ClientProfileManager.instance.isEditCallbackWired

    private let octopus: OctopusSDK = OctopusSDKProvider.instance.octopus

    func apply(_ mode: Mode) {
        octopus.debugOverrideExposeClientUserId(mode.overrideValue)
        appliedMode = mode
    }

    /// Wire or unwire the host's `onNavigateToProfileCallback` live, so both halves of the AND-gate
    /// can be exercised from the scenario (flag on + unwired → native profile; flag on + wired →
    /// host / Octopus activity).
    func setCallbackWired(_ wired: Bool) {
        ClientProfileManager.instance.setCallbackWired(wired)
        callbackWired = wired
    }

    /// Wire or unwire the host's `onNavigateToProfileEditCallback` live, so the connected-user
    /// Activity menu's "Edit my profile" item can be exercised both shown (wired → host edit screen)
    /// and hidden (unwired).
    func setEditCallbackWired(_ wired: Bool) {
        ClientProfileManager.instance.setEditCallbackWired(wired)
        editCallbackWired = wired
    }
}
