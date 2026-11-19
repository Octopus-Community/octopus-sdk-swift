//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusGrpcModels
@testable import OctopusCore

/// The server says why the access to the community is denied. A server that does not say it (an older one, or one
/// naming a reason this version does not know) still denies the access: the reason is then unknown.
struct CommunityNoAccessReasonTests {
    private typealias Response = Com_Octopuscommunity_CanAccessCommunityResponse

    @Test func eachServerReasonMapsToItsCase() {
        #expect(CommunityNoAccessReason(from: refusal { $0.noAccessCohort = .init() }) == .cohort)
        #expect(CommunityNoAccessReason(from: refusal { $0.memberExcluded = .init() }) == .memberExcluded)
        #expect(CommunityNoAccessReason(from: refusal { $0.accountDeleted = .init() }) == .accountDeleted)
    }

    @Test func aRefusalWithoutReasonIsUnknown() {
        #expect(CommunityNoAccessReason(from: refusal { _ in }) == .unknown)
    }

    /// An ended session is replaced rather than stored: were it mapped, it would only be as a refusal without reason.
    @Test func anEndedSessionIsNoReasonOfItsOwn() {
        #expect(CommunityNoAccessReason(from: refusal { $0.sessionEnded = .init() }) == .unknown)
    }

    @Test func aGrantedAccessHasNoReason() {
        let response = Response.with {
            $0.canAccessCommunity = true
            $0.noAccessCohort = .init()
        }

        #expect(CommunityNoAccessReason(from: response) == nil)
        #expect(UserConfig(from: response).noAccessReason == nil)
        #expect(UserConfig(from: response).canAccessCommunity)
    }

    @Test func aBanKeepsItsDetails() {
        let response = refusal {
            $0.accountBanned = .with {
                $0.nickname = "marie_l92"
                $0.policyName = "Job applications"
                $0.policyDescription = "Desc"
                $0.contactEmail = "a@b.co"
            }
        }

        #expect(CommunityNoAccessReason(from: response) == .accountBanned(.init(
            nickname: "marie_l92", policyName: "Job applications", policyDescription: "Desc",
            contactEmail: "a@b.co")))
    }

    @Test func aBanWithoutNicknameOrEmailHasNone() {
        let response = refusal {
            $0.accountBanned = .with {
                $0.policyName = "Job applications"
                $0.policyDescription = "Desc"
            }
        }

        #expect(CommunityNoAccessReason(from: response) == .accountBanned(.init(
            nickname: nil, policyName: "Job applications", policyDescription: "Desc", contactEmail: nil)))
    }

    @Test func emptyBanStringsAreAbsent() {
        let response = refusal {
            $0.accountBanned = .with {
                $0.nickname = ""
                $0.policyName = "Job applications"
                $0.contactEmail = ""
            }
        }

        #expect(CommunityNoAccessReason(from: response) == .accountBanned(.init(
            nickname: nil, policyName: "Job applications", policyDescription: "", contactEmail: nil)))
    }

    /// A nickname or an address made of spaces would leave "@" or "contact" hanging in the sentences.
    @Test func blankBanStringsAreAbsent() {
        let response = refusal {
            $0.accountBanned = .with {
                $0.nickname = "  "
                $0.policyName = "Job applications"
                $0.contactEmail = " \n"
            }
        }

        #expect(CommunityNoAccessReason(from: response) == .accountBanned(.init(
            nickname: nil, policyName: "Job applications", policyDescription: "", contactEmail: nil)))
    }

    @Test func aClosureKindMapsToItsReason() {
        #expect(CommunityNoAccessReason(closureKind: .closed) == .closed)
        #expect(CommunityNoAccessReason(closureKind: .temporarilyDisabled) == .temporarilyDisabled)
    }

    @Test func aRefusedUserConfigAlwaysHasAReason() {
        #expect(UserConfig(canAccessCommunity: false, accessDeniedMessage: "m").noAccessReason == .unknown)
        #expect(UserConfig(canAccessCommunity: true, accessDeniedMessage: nil, noAccessReason: .cohort)
            .noAccessReason == nil)
    }

    @Test func theBackMessageIsKeptAndAnEmptyOneDropped() {
        #expect(UserConfig(from: refusal { $0.communityDisabledMessage = "" }).accessDeniedMessage == nil)
        #expect(UserConfig(from: refusal { $0.communityDisabledMessage = "Msg" }).accessDeniedMessage == "Msg")
        #expect(UserConfig(from: refusal { $0.memberExcluded = .init() }).noAccessReason == .memberExcluded)
    }

    private func refusal(_ populate: (inout Response) -> Void) -> Response {
        var response = Response()
        response.canAccessCommunity = false
        populate(&response)
        return response
    }
}
