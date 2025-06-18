//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

extension ModerationReason {
    var displayableString: DisplayableString {
        return switch self {
        case .hatefulConduct:
                .localizationKey("Moderation.Reason.HatefulConduct")
        case .bullyingOrHarassment:
                .localizationKey("Moderation.Reason.BullyingOrHarassment")
        case .graphicViolence:
                .localizationKey("Moderation.Reason.GraphicViolence")
        case .aggressive:
                .localizationKey("Moderation.Reason.Aggressive")
        case .violentInstigation:
                .localizationKey("Moderation.Reason.ViolentInstigation")
        case .sexuallySuggestive:
                .localizationKey("Moderation.Reason.SexualSuggestivity")
        case .adultNudityOrSexualActivity:
                .localizationKey("Moderation.Reason.AdultNudityOrSexualActivity")
        case .sexualSolicitationOrExplicitLanguage:
                .localizationKey("Moderation.Reason.SexualSolicitationOrExplicitLanguage")
        case .adultSexualExploitation:
                .localizationKey("Moderation.Reason.AdultSexualExploitation")
        case .childSexualAbuseMaterial:
                .localizationKey("Moderation.Reason.ChildSexualAbuseMaterial")
        case .suicideOrSelfHarm:
                .localizationKey("Moderation.Reason.SuicideOrSelfHarm")
        case .regulatedGoods:
                .localizationKey("Moderation.Reason.RegulatedGoods")
        case .humanExploitation:
                .localizationKey("Moderation.Reason.HumanExploitation")
        case .terrorismOrganizedHateDangerousOrganizationsOrIndividual:
                .localizationKey("Moderation.Reason.TerrorismOrganizedHateDangerousOrganizationsOrIndividual")
        case .harmOrCrime:
                .localizationKey("Moderation.Reason.HarmOrCrime")
        case .spamOrScams:
                .localizationKey("Moderation.Reason.SpamOrScams")
        case .impersonation:
                .localizationKey("Moderation.Reason.Impersonation")
        case .misinformation:
                .localizationKey("Moderation.Reason.Misinformation")
        case .personallyIdentifiableInformation:
                .localizationKey("Moderation.Reason.PersonallyIdentifiableInformation")
        case .usernamePolicy:
                .localizationKey("Moderation.Reason.UsernamePolicy")
        case .copyrightOrIntellectualPropertyInfringement:
                .localizationKey("Moderation.Reason.CopyrightOrIntellectualPropertyInfringement")
        case let .other(message):
            if let message {
                .localizedString(message)
            } else {
                .localizationKey("Moderation.Reason.Other")
            }
        }
    }
}
