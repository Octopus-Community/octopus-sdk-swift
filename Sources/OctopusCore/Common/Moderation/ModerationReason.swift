//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import GrpcModels
import SwiftProtobuf

public enum ModerationReason: Equatable, Sendable, CaseIterable, Hashable {
    /// Hate speech or discriminatory content
    case hateSpeechOrDiscriminatoryContent
    /// Harassment, intimidation, or threats toward a user
    case harassmentIntimidationOrThreats
    /// Violent content or content inciting violence
    case violentContentOrIncitingViolence
    /// Pornography or sexually explicit content
    case pornographyOrSexuallyExplicitContent
    /// Misinformation or fake news
    case misinformationOrFakeNews
    /// Spam, promotional, or unsolicited advertising content
    case spamPromotionalOrUnsolicitedAdvertisingContent
    /// Sharing personal or private information
    case sharingPersonalOrPrivateInformation
    /// Illegal content
    case illegalContent
    /// Terrorism
    case terrorism
    /// Child exploitation
    case childExploitation
    /// Impersonation or identity theft
    case impersonationOrIdentityTheft
    /// Promotes suicide, self-injury, or eating disorders
    case promotesSuicideSelfInjuryOrEatingDisorders
    /// Other reasons
    case other(String?)

    private var order: Int {
        return switch self {
        case .hateSpeechOrDiscriminatoryContent: 0
        case .harassmentIntimidationOrThreats: 1
        case .violentContentOrIncitingViolence: 2
        case .pornographyOrSexuallyExplicitContent: 3
        case .misinformationOrFakeNews: 4
        case .spamPromotionalOrUnsolicitedAdvertisingContent: 5
        case .sharingPersonalOrPrivateInformation: 6
        case .illegalContent: 7
        case .terrorism: 8
        case .childExploitation: 9
        case .impersonationOrIdentityTheft: 10
        case .promotesSuicideSelfInjuryOrEatingDisorders: 11
        case .other: 12
        }
    }

    static public var allCases: [ModerationReason] {
        // use a Set to avoid putting multiple .other in the array
        Set(
            Com_Octopuscommunity_StatusReasonCode.allCases
                .filter { $0 != .unspecifiedReason }
                .map { ModerationReason(from: $0) }
        )
        .sorted { $0.order < $1.order }
    }
}

extension ModerationReason {
    var protoValue: Com_Octopuscommunity_StatusReasonCode {
        return switch self {
        case .hateSpeechOrDiscriminatoryContent: .hte
        case .harassmentIntimidationOrThreats: .hrs
        case .violentContentOrIncitingViolence: .vlc
        case .pornographyOrSexuallyExplicitContent: .sxc
        case .misinformationOrFakeNews: .fkc
        case .spamPromotionalOrUnsolicitedAdvertisingContent: .spm
        case .sharingPersonalOrPrivateInformation: .pii
        case .illegalContent: .ill
        case .terrorism: .ter
        case .childExploitation: .cex
        case .impersonationOrIdentityTheft: .imp
        case .promotesSuicideSelfInjuryOrEatingDisorders: .ssh
        case .other: .oth
        }
    }

    init(from protoValue: Com_Octopuscommunity_StatusReasonCode) {
        self = switch protoValue {
        case .hte:                  .hateSpeechOrDiscriminatoryContent
        case .hrs:                  .harassmentIntimidationOrThreats
        case .vlc:                  .violentContentOrIncitingViolence
        case .sxc:                  .pornographyOrSexuallyExplicitContent
        case .fkc:                  .misinformationOrFakeNews
        case .spm:                  .spamPromotionalOrUnsolicitedAdvertisingContent
        case .pii:                  .sharingPersonalOrPrivateInformation
        case .ill:                  .illegalContent
        case .ter:                  .terrorism
        case .cex:                  .childExploitation
        case .imp:                  .impersonationOrIdentityTheft
        case .ssh:                  .promotesSuicideSelfInjuryOrEatingDisorders
        case .unspecifiedReason, .oth, .UNRECOGNIZED:   .other(nil)
        }
    }
}
