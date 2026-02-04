//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

extension OctopusEvent {
    /// A reason to report a content or a profile
    public enum ReportReason: Sendable {
        // Hate speech, discrimination, and harassment
        case hateSpeechOrDiscriminationOrHarassment
        // Explicit or inappropriate content
        case explicitOrInappropriateContent
        // Violence and terrorism
        case violenceAndTerrorism
        // Spam and scams
        case spamAndScams
        // Suicide and self-harm
        case suicideAndSelfHarm
        // Fake profiles and impersonation
        case fakeProfilesAndImpersonation
        // Child exploitation or abuse
        case childExploitationOrAbuse
        // Intellectual property violation
        case intellectualPropertyViolation
        /// Other
        case other
    }
}

extension OctopusEvent.ReportReason {
    init(from kind: SdkEvent.ReportReason) {
        self = switch kind {
        case .hateSpeechOrDiscriminationOrHarassment: .hateSpeechOrDiscriminationOrHarassment
        case .explicitOrInappropriateContent: .explicitOrInappropriateContent
        case .violenceAndTerrorism: .violenceAndTerrorism
        case .spamAndScams: .spamAndScams
        case .suicideAndSelfHarm: .suicideAndSelfHarm
        case .fakeProfilesAndImpersonation: .fakeProfilesAndImpersonation
        case .childExploitationOrAbuse: .childExploitationOrAbuse
        case .intellectualPropertyViolation: .intellectualPropertyViolation
        case .other: .other
        }
    }
}
