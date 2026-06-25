//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
@_spi(OctopusInternalTesting) import Octopus
import OctopusCore

/// View model of ContentOptionsView.
///
/// Applies a DEBUG-only override of the community content options (OCT-1426), so the per-content-type
/// picture/poll gating can be exercised in the sample without a backend-driven config (the backend
/// serves a single config per key, so presets are the only way to cover the full matrix).
@MainActor
class ContentOptionsViewModel: ObservableObject {
    enum Preset: Int, CaseIterable, Identifiable {
        case allEnabled = 1
        case postNoPicturesNoPolls = 2
        case commentNoPictures = 3
        case replyNoPictures = 4

        var id: Int { rawValue }

        var label: String {
            switch self {
            case .allEnabled: "Preset 1 · All enabled (default / no-op)"
            case .postNoPicturesNoPolls: "Preset 2 · Post: no pictures, no polls"
            case .commentNoPictures: "Preset 3 · Comment: no pictures"
            case .replyNoPictures: "Preset 4 · Reply: no pictures"
            }
        }

        var testId: String { "qa-preset-contentOptions-\(rawValue)" }

        var options: ContentOptions {
            switch self {
            case .allEnabled:
                .allEnabled
            case .postNoPicturesNoPolls:
                ContentOptions(post: .init(enablePictures: false, enablePolls: false),
                               comment: .init(enablePictures: true),
                               reply: .init(enablePictures: true))
            case .commentNoPictures:
                ContentOptions(post: .init(enablePictures: true, enablePolls: true),
                               comment: .init(enablePictures: false),
                               reply: .init(enablePictures: true))
            case .replyNoPictures:
                ContentOptions(post: .init(enablePictures: true, enablePolls: true),
                               comment: .init(enablePictures: true),
                               reply: .init(enablePictures: false))
            }
        }
    }

    @Published private(set) var appliedPreset: Preset?

    private let octopus: OctopusSDK = OctopusSDKProvider.instance.octopus

    func apply(_ preset: Preset) {
        octopus.debugOverrideContentOptions(preset.options)
        appliedPreset = preset
    }

    func clearOverride() {
        octopus.debugOverrideContentOptions(nil)
        appliedPreset = nil
    }

    func describe(_ preset: Preset) -> String {
        let options = preset.options
        return """
        post: pictures=\(options.post.enablePictures), polls=\(options.post.enablePolls)
        comment: pictures=\(options.comment.enablePictures)
        reply: pictures=\(options.reply.enablePictures)
        """
    }
}
