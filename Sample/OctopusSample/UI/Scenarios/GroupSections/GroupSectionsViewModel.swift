//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
@_spi(OctopusInternalTesting) import Octopus
import OctopusCore

/// View model of GroupSectionsView.
///
/// Applies a DEBUG-only override that redistributes the community groups into mock client sections,
/// so the sectioned group-list rendering (section title padding + inter-section separator) can be
/// exercised in the sample. The demo community serves no client sections, so this override is the
/// only way to observe the separators without a specifically configured backend community.
@MainActor
class GroupSectionsViewModel: ObservableObject {
    enum Preset: Int, CaseIterable, Identifiable {
        case twoSections = 1
        case threeSections = 2

        var id: Int { rawValue }

        var label: String {
            switch self {
            case .twoSections: "Preset 1 · 2 sections (Popular, Discover)"
            case .threeSections: "Preset 2 · 3 sections (Popular, Sports, Lifestyle)"
            }
        }

        var testId: String { "qa-preset-groupSections-\(rawValue)" }

        var sectionNames: [String] {
            switch self {
            case .twoSections: ["Popular", "Discover"]
            case .threeSections: ["Popular", "Sports", "Lifestyle"]
            }
        }
    }

    @Published private(set) var appliedPreset: Preset?

    private let octopus: OctopusSDK = OctopusSDKProvider.instance.octopus

    func apply(_ preset: Preset) {
        octopus.debugOverrideTopicSections(mockSectionNames: preset.sectionNames)
        appliedPreset = preset
    }

    func clearOverride() {
        octopus.debugOverrideTopicSections(mockSectionNames: [])
        appliedPreset = nil
    }
}
