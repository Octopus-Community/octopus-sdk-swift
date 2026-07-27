//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
@_spi(OctopusInternalTesting) import Octopus
import OctopusCore

/// View model of TermsAcceptanceModeView.
///
/// Applies a DEBUG-only override of the community terms-acceptance mode, so the explicit-consent
/// bottom sheet can be exercised in the sample without a backend-driven config.
@MainActor
class TermsAcceptanceModeViewModel: ObservableObject {
    enum Preset: Int, CaseIterable, Identifiable {
        case implicit = 1
        case explicitMultiCheckbox = 2
        case explicitSingleCheckbox = 3

        var id: Int { rawValue }

        var label: String {
            switch self {
            case .implicit: "Mode 1 · Implicit (default / legal footer)"
            case .explicitMultiCheckbox: "Mode 2 · Explicit — one checkbox per document"
            case .explicitSingleCheckbox: "Mode 3 · Explicit — single combined checkbox"
            }
        }

        var testId: String { "qa-preset-termsAcceptanceMode-\(rawValue)" }

        var mode: TermsAcceptanceMode {
            switch self {
            case .implicit: .implicit
            case .explicitMultiCheckbox: .explicitMultiCheckbox
            case .explicitSingleCheckbox: .explicitSingleCheckbox
            }
        }
    }

    @Published private(set) var appliedPreset: Preset?

    private let octopus: OctopusSDK = OctopusSDKProvider.instance.octopus

    func apply(_ preset: Preset) {
        octopus.debugOverrideTermsAcceptanceMode(preset.mode)
        appliedPreset = preset
    }

    func clearOverride() {
        octopus.debugOverrideTermsAcceptanceMode(nil)
        appliedPreset = nil
    }
}
