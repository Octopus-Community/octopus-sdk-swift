//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusCore

/// `Status(status:reasons:)`: the stored moderation status and reason codes of a content become its public `Status`.
struct StatusMappingTests {

    @Test func publishedIgnoresTheReasons() {
        let status = Status(status: .published, reasons: [StorableStatusReason(code: .hte, message: "Hate")])

        #expect(status == .published)
    }

    @Test func moderatedMapsEveryReasonCode() {
        let expectations: [(StorableStatusReason.Code, ModerationReason)] = [
            (.hte, .hatefulConduct),
            (.hrs, .bullyingOrHarassment),
            (.gv, .graphicViolence),
            (.agg, .aggressive),
            (.vlc, .violentInstigation),
            (.sxc, .sexuallySuggestive),
            (.nud, .adultNudityOrSexualActivity),
            (.soli, .sexualSolicitationOrExplicitLanguage),
            (.aex, .adultSexualExploitation),
            (.cex, .childSexualAbuseMaterial),
            (.ssh, .suicideOrSelfHarm),
            (.ill, .regulatedGoods),
            (.hex, .humanExploitation),
            (.ter, .terrorismOrganizedHateDangerousOrganizationsOrIndividual),
            (.hc, .harmOrCrime),
            (.spm, .spamOrScams),
            (.imp, .impersonation),
            (.mis, .misinformation),
            (.pii, .personallyIdentifiableInformation),
            (.up, .usernamePolicy),
            (.cip, .copyrightOrIntellectualPropertyInfringement)
        ]

        for (code, expected) in expectations {
            // The message only matters for `.oth`: a known code never carries it over.
            let status = Status(status: .moderated, reasons: [StorableStatusReason(code: code, message: "Ignored")])
            #expect(status == .moderated(reasons: [expected]), "code \(code)")
        }
    }

    @Test func moderatedKeepsEveryReasonInOrder() {
        let status = Status(status: .moderated, reasons: [
            StorableStatusReason(code: .spm, message: ""),
            StorableStatusReason(code: .hte, message: ""),
            StorableStatusReason(code: .oth, message: "Off topic")
        ])

        #expect(status == .moderated(reasons: [.spamOrScams, .hatefulConduct, .other("Off topic")]))
    }

    @Test func moderatedWithoutReasonsHasAnEmptyList() {
        #expect(Status(status: .moderated, reasons: []) == .moderated(reasons: []))
    }

    @Test func otherAndUnknownCodesCarryTheirMessage() {
        let status = Status(status: .moderated, reasons: [
            StorableStatusReason(code: .oth, message: "Off topic"),
            StorableStatusReason(code: .oth, message: ""),
            StorableStatusReason(code: .UNRECOGNIZED(999), message: "Reason added after this SDK version")
        ])

        // An empty message becomes nil, so the UI can fall back to its generic wording.
        #expect(status == .moderated(reasons: [
            .other("Off topic"),
            .other(nil),
            .other("Reason added after this SDK version")
        ]))
    }

    @Test func unknownStatusesAreOther() {
        #expect(Status(status: .unknown, reasons: []) == .other)
        #expect(Status(status: .UNRECOGNIZED(42), reasons: [StorableStatusReason(code: .hte, message: "")]) == .other)
    }
}
