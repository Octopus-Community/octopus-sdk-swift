//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

extension ReactionKind {
    @available(iOS 15, *)
    private var accessibilityKey: String.LocalizationValue {
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

    private var description: String {
        switch self {
        case .heart: "Like"
        case .joy: "Joy"
        case .mouthOpen: "Surprise"
        case .clap: "Congrats"
        case .cry: "Cry"
        case .rage: "Rage"
        case .unknown: "Unknown"
        }
    }

    var accessibilityValue: String {
        if #available(iOS 15, *) {
            return String(localized: accessibilityKey, bundle: .module)
        } else {
            return description
        }
    }
}
