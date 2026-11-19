//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusGrpcModels
@testable import OctopusCore

/// `ReportReason`: the reasons a user picks from when reporting a content or a profile, and their proto codes.
struct ReportReasonMappingTests {

    @Test func everyReasonRoundTripsThroughItsProtoCode() {
        for reason in ReportReason.allCases {
            #expect(ReportReason(from: reason.protoValue) == reason, "reason \(reason)")
        }
    }

    @Test func illegalActivitiesAreSentAsTheirOwnCode() {
        // The back end files the deprecated `.reportImp` under spam: moderation must receive `.reportIll`.
        #expect(ReportReason.fakeProfilesAndImpersonation.protoValue == .reportIll)
    }

    @Test func noReasonSendsTheDeprecatedImpersonationCode() {
        for reason in ReportReason.allCases {
            #expect(reason.protoValue != .reportImp, "reason \(reason)")
        }
    }

    @Test func bothIllegalActivitiesCodesReadAsTheSameReason() {
        // `.reportImp` is the code this reason was sent as before: it still maps to it.
        #expect(ReportReason(from: .reportIll) == .fakeProfilesAndImpersonation)
        #expect(ReportReason(from: .reportImp) == .fakeProfilesAndImpersonation)
    }

    @Test func codesWithoutTheirOwnReasonBecomeOther() {
        let codes: [Com_Octopuscommunity_ReportReasonCode] = [
            .reportOth, .reportUnspecifiedReason, .UNRECOGNIZED(999)
        ]

        for code in codes {
            #expect(ReportReason(from: code) == .other, "code \(code)")
        }
    }

    @Test func allCasesListsEachReasonOnceInDisplayOrder() {
        // Several proto codes fold into `.other`: it must still be offered once, and last.
        #expect(ReportReason.allCases == [
            .hateSpeechOrDiscriminationOrHarassment,
            .explicitOrInappropriateContent,
            .violenceAndTerrorism,
            .spamAndScams,
            .suicideAndSelfHarm,
            .fakeProfilesAndImpersonation,
            .childExploitationOrAbuse,
            .intellectualPropertyViolation,
            .other
        ])
    }
}
