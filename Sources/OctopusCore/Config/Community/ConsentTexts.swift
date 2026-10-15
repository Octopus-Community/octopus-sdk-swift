//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

/// The consent wordings a community sets in its back-office, already in the member's language, written in markdown
/// (links, bold, italic, line breaks). Each case carries the texts of one ``TermsAcceptanceMode``, and the UI only
/// uses them when that mode is the community's current one. A `nil` field keeps the SDK wording for that field.
public enum ConsentTexts: Equatable, Sendable {
    /// Notice shown under the post, comment and reply composers.
    case implicit(notice: String?)
    /// Labels of the three checkboxes, one per legal document.
    case multiCheckbox(termsLabel: String?, privacyLabel: String?, rulesLabel: String?)
    /// Label of the single checkbox, and the text shown under it.
    case singleCheckbox(label: String?, belowText: String?)
}

extension ConsentTexts {
    /// Maps the proto message, `nil` when it sets no mode. A field left empty, or made only of whitespace, maps to
    /// `nil` so that field keeps the SDK wording.
    init?(from proto: Com_Octopuscommunity_ConsentTexts) {
        switch proto.mode {
        case let .implicit(texts)?:
            self = .implicit(notice: texts.notice.nilIfBlank)
        case let .multiCheckbox(texts)?:
            self = .multiCheckbox(termsLabel: texts.termsLabel.nilIfBlank,
                                  privacyLabel: texts.privacyLabel.nilIfBlank,
                                  rulesLabel: texts.rulesLabel.nilIfBlank)
        case let .singleCheckbox(texts)?:
            self = .singleCheckbox(label: texts.label.nilIfBlank, belowText: texts.belowText.nilIfBlank)
        case nil:
            return nil
        }
    }

    /// Stable CoreData raw value of the case.
    var storageMode: Int16 {
        switch self {
        case .implicit: 0
        case .multiCheckbox: 1
        case .singleCheckbox: 2
        }
    }

    /// Rebuilds the texts from their stored columns, `nil` when none were stored.
    init?(from entity: CommunityConfigEntity) {
        guard let mode = entity.consentTextsMode?.int16Value else { return nil }
        switch mode {
        case 0:
            self = .implicit(notice: entity.consentImplicitNotice)
        case 1:
            self = .multiCheckbox(termsLabel: entity.consentTermsLabel,
                                  privacyLabel: entity.consentPrivacyLabel,
                                  rulesLabel: entity.consentRulesLabel)
        case 2:
            self = .singleCheckbox(label: entity.consentSingleLabel, belowText: entity.consentBelowText)
        default:
            return nil
        }
    }
}
