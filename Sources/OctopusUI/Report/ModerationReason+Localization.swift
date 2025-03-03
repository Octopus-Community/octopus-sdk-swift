//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

extension ModerationReason {
    var displayableString: DisplayableString {
        return switch self {
        case .hateSpeechOrDiscriminatoryContent:
                .localizationKey("Moderation.Reason.HateSpeechOrDiscriminatoryContent")
        case .harassmentIntimidationOrThreats:
            .localizationKey("Moderation.Reason.HarassmentIntimidationOrThreats")
        case .violentContentOrIncitingViolence:
            .localizationKey("Moderation.Reason.ViolentContentOrIncitingViolence")
        case .pornographyOrSexuallyExplicitContent:
            .localizationKey("Moderation.Reason.PornographyOrSexuallyExplicitContent")
        case .misinformationOrFakeNews:
            .localizationKey("Moderation.Reason.MisinformationOrFakeNews")
        case .spamPromotionalOrUnsolicitedAdvertisingContent:
            .localizationKey("Moderation.Reason.SpamPromotionalOrUnsolicitedAdvertisingContent")
        case .sharingPersonalOrPrivateInformation:
            .localizationKey("Moderation.Reason.SharingPersonalOrPrivateInformation")
        case .illegalContent:
            .localizationKey("Moderation.Reason.IllegalContent")
        case .terrorism:
            .localizationKey("Moderation.Reason.Terrorism")
        case .childExploitation:
            .localizationKey("Moderation.Reason.ChildExploitation")
        case .impersonationOrIdentityTheft:
            .localizationKey("Moderation.Reason.ImpersonationOrIdentityTheft")
        case .promotesSuicideSelfInjuryOrEatingDisorders:
            .localizationKey("Moderation.Reason.PromotesSuicideSelfInjuryOrEatingDisorders")
        case let .other(message):
            if let message {
                .localizedString(message)
            } else {
                .localizationKey("Moderation.Reason.Other")
            }
        }
    }
}
