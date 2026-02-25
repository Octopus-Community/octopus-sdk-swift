//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

extension ReactionKind {
    private var accessibilityKey: String {
        switch self {
        case .heart: "Accessibility.Reaction.Like"
        case .joy: "Accessibility.Reaction.Joy"
        case .mouthOpen: "Accessibility.Reaction.Surprise"
        case .clap: "Accessibility.Reaction.Congrats"
        case .cry: "Accessibility.Reaction.Cry"
        case .rage: "Accessibility.Reaction.Rage"
        case .unknown: "Accessibility.Reaction.Unknown"
        }
    }

    func accessibilityValue(locale: Locale?) -> String {
        L10n(accessibilityKey, locale: locale)
    }
}
