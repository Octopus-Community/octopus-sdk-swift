//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
@_spi(OctopusInternalTesting) import Octopus
import OctopusCore

/// View model of ProfileFieldsLockView.
///
/// Applies a DEBUG-only override of the community per-field profile lock (OCT-1487), so the lock can
/// be exercised in the sample without a backend-driven config. Each preset maps to one of the lock
/// combinations described in the PRD.
@MainActor
class ProfileFieldsLockViewModel: ObservableObject {
    enum Preset: Int, CaseIterable, Identifiable {
        case allEditable = 1
        case pseudoAvatarReadOnlyBioHidden = 2
        case bioOnlyEditable = 3

        var id: Int { rawValue }

        // Generic labels (no client name) — kept in sync with the pm-tools scenario catalog.
        var label: String {
            switch self {
            case .allEditable: "Preset 1 · All editable (default / no-op)"
            case .pseudoAvatarReadOnlyBioHidden: "Preset 2 · Pseudo + avatar read-only, bio hidden"
            case .bioOnlyEditable: "Preset 3 · Bio-only editable"
            }
        }

        var testId: String { "qa-preset-profileFieldsLock-\(rawValue)" }

        var lock: ProfileFieldsLock {
            switch self {
            case .allEditable:
                .allEditable
            case .pseudoAvatarReadOnlyBioHidden:
                ProfileFieldsLock(nickname: .readOnly, avatar: .readOnly, bio: .disabled)
            case .bioOnlyEditable:
                ProfileFieldsLock(nickname: .readOnly, avatar: .readOnly, bio: .editable)
            }
        }
    }

    @Published private(set) var appliedPreset: Preset?

    private let octopus: OctopusSDK = OctopusSDKProvider.instance.octopus

    func apply(_ preset: Preset) {
        octopus.debugOverrideProfileFieldsLock(preset.lock)
        appliedPreset = preset
    }

    func clearOverride() {
        octopus.debugOverrideProfileFieldsLock(nil)
        appliedPreset = nil
    }

    func describe(_ preset: Preset) -> String {
        let lock = preset.lock
        return "nickname: \(lock.nickname)\navatar: \(lock.avatar)\nbio: \(lock.bio)"
    }
}
