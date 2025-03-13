//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

extension ReportReason {
    var displayableString: DisplayableString {
        return switch self {
        case .hateSpeechOrDiscriminationOrHarassment:
                .localizationKey("Report.Reason.HateSpeechOrDiscriminationOrHarassment")
        case .explicitOrInappropriateContent:
                .localizationKey("Report.Reason.ExplicitOrInappropriateContent")
        case .violenceAndTerrorism:
                .localizationKey("Report.Reason.ViolenceAndTerrorism")
        case .spamAndScams:
                .localizationKey("Report.Reason.SpamAndScams")
        case .suicideAndSelfHarm:
                .localizationKey("Report.Reason.SuicideAndSelfHarm")
        case .fakeProfilesAndImpersonation:
                .localizationKey("Report.Reason.FakeProfilesAndImpersonation")
        case .childExploitationOrAbuse:
                .localizationKey("Report.Reason.ChildExploitationOrAbuse")
        case .intellectualPropertyViolation:
                .localizationKey("Report.Reason.IntellectualPropertyViolation")
        case .other:
                .localizationKey("Report.Reason.Other")
        }
    }
}
