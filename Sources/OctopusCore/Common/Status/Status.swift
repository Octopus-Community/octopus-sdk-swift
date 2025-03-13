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
                case .hte: return .hatefulConduct
                case .hrs: return .bullyingOrHarassment
                case .gv: return .graphicViolence
                case .agg: return .aggressive
                case .vlc: return .violentInstigation
                case .sxc: return .sexuallySuggestive
                case .nud: return .adultNudityOrSexualActivity
                case .soli: return .sexualSolicitationOrExplicitLanguage
                case .aex: return .adultSexualExploitation
                case .cex: return .childSexualAbuseMaterial
                case .ssh: return .suicideOrSelfHarm
                case .ill: return .regulatedGoods
                case .hex: return .humanExploitation
                case .ter: return .terrorismOrganizedHateDangerousOrganizationsOrIndividual
                case .hc: return .harmOrCrime
                case .spm: return .spamOrScams
                case .imp: return .impersonation
                case .mis: return .misinformation
                case .pii: return .personallyIdentifiableInformation
                case .up: return .usernamePolicy
                case .cip: return .copyrightOrIntellectualPropertyInfringement
                case .oth, .UNRECOGNIZED:   return .other(reason.message.nilIfEmpty)
                }
            }
            self = .moderated(reasons: reasons)
        case .unknown, .UNRECOGNIZED:
            self = .other
        }
    }
}
