//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels
import SwiftProtobuf

public enum ReportReason: Equatable, Sendable, CaseIterable, Hashable {
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

    private var order: Int {
        return switch self {
        case .hateSpeechOrDiscriminationOrHarassment: 0
        case .explicitOrInappropriateContent: 1
        case .violenceAndTerrorism: 2
        case .spamAndScams: 3
        case .suicideAndSelfHarm: 4
        case .fakeProfilesAndImpersonation: 5
        case .childExploitationOrAbuse: 6
        case .intellectualPropertyViolation: 7
        case .other: 8
        }
    }

    static public var allCases: [ReportReason] {
        // use a Set to avoid putting multiple .other in the array
        Set(
            Com_Octopuscommunity_ReportReasonCode.allCases
                .filter { $0 != .reportUnspecifiedReason }
                .map { ReportReason(from: $0) }
        )
        .sorted { $0.order < $1.order }
    }
}

extension ReportReason {
    var protoValue: Com_Octopuscommunity_ReportReasonCode {
        return switch self {
        case .hateSpeechOrDiscriminationOrHarassment: .reportHteHrs
        case .explicitOrInappropriateContent: .reportSxc
        case .violenceAndTerrorism: .reportVlcTer
        case .spamAndScams: .reportSpm
        case .suicideAndSelfHarm: .reportSsh
        case .fakeProfilesAndImpersonation: .reportImp
        case .childExploitationOrAbuse: .reportCex
        case .intellectualPropertyViolation: .reportIpv
        case .other: .reportOth
        }
    }

    init(from protoValue: Com_Octopuscommunity_ReportReasonCode) {
        self = switch protoValue {
        case .reportHteHrs: .hateSpeechOrDiscriminationOrHarassment
        case .reportSxc: .explicitOrInappropriateContent
        case .reportVlcTer: .violenceAndTerrorism
        case .reportSpm: .spamAndScams
        case .reportSsh: .suicideAndSelfHarm
        case .reportImp: .fakeProfilesAndImpersonation
        case .reportCex: .childExploitationOrAbuse
        case .reportIpv: .intellectualPropertyViolation
        case .reportUnspecifiedReason, .reportOth, .UNRECOGNIZED:   .other
        }
    }
}
