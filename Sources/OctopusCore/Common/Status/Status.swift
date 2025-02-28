//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

public enum Status: Equatable, Sendable {
    case published
    case moderated(reasons: [ModerationReason])
    case other
}

extension Status {
    init(status: StorableStatus, reasons: [StorableStatusReason]) {
        switch status {
        case .published:
            self = .published
        case .moderated:
            let reasons: [ModerationReason] = reasons.map { reason -> ModerationReason in
                switch reason.code {
                case .hte:                  return .hateSpeechOrDiscriminatoryContent
                case .hrs:                  return .harassmentIntimidationOrThreats
                case .vlc:                  return .violentContentOrIncitingViolence
                case .sxc:                  return .pornographyOrSexuallyExplicitContent
                case .fkc:                  return .misinformationOrFakeNews
                case .spm:                  return .spamPromotionalOrUnsolicitedAdvertisingContent
                case .pii:                  return .sharingPersonalOrPrivateInformation
                case .ill:                  return .illegalContent
                case .ter:                  return .terrorism
                case .cex:                  return .childExploitation
                case .imp:                  return .impersonationOrIdentityTheft
                case .ssh:                  return .promotesSuicideSelfInjuryOrEatingDisorders
                case .oth, .UNRECOGNIZED:   return .other(reason.message.nilIfEmpty)
                }
            }
            self = .moderated(reasons: reasons)
        case .unknown, .UNRECOGNIZED:
            self = .other
        }
    }
}
