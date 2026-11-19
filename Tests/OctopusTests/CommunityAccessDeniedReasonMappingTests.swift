//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import Octopus
@testable import OctopusCore

/// The reason given to the host app mirrors the internal one: set exactly when the access is known to be denied,
/// so that it never disagrees with `hasAccessToCommunity`.
struct CommunityAccessDeniedReasonMappingTests {
    private static let ban = CommunityNoAccessReason.accountBanned(.init(
        nickname: "marie_l92", policyName: "Job applications", policyDescription: "Desc", contactEmail: "a@b.co"))

    @Test func eachInternalReasonMapsToItsPublicCase() {
        #expect(OctopusCommunityAccessDeniedReason(from: .cohort) == .notInCohort)
        #expect(OctopusCommunityAccessDeniedReason(from: .temporarilyDisabled) == .communityTemporarilyDisabled)
        #expect(OctopusCommunityAccessDeniedReason(from: .closed) == .communityClosed)
        #expect(OctopusCommunityAccessDeniedReason(from: .memberExcluded) == .memberExcluded)
        #expect(OctopusCommunityAccessDeniedReason(from: Self.ban) == .accountBanned)
        #expect(OctopusCommunityAccessDeniedReason(from: .accountDeleted) == .accountDeleted)
        #expect(OctopusCommunityAccessDeniedReason(from: .unknown) == .unknown)
    }

    @Test func noKnownAccessStateHasNoReason() {
        #expect(OctopusCommunityAccessDeniedReason(userConfig: nil) == nil)
    }

    @Test func aGrantedAccessHasNoReason() {
        #expect(OctopusCommunityAccessDeniedReason(
            userConfig: UserConfig(canAccessCommunity: true, accessDeniedMessage: nil)) == nil)
    }

    @Test(arguments: [
        nil,
        UserConfig(canAccessCommunity: true, accessDeniedMessage: nil),
        UserConfig(canAccessCommunity: true, accessDeniedMessage: nil, noAccessReason: .cohort),
        UserConfig(canAccessCommunity: false, accessDeniedMessage: nil),
        UserConfig(canAccessCommunity: false, accessDeniedMessage: "msg", noAccessReason: .closed),
        UserConfig(canAccessCommunity: false, accessDeniedMessage: "msg", noAccessReason: ban)
    ])
    func theReasonIsSetExactlyWhenTheAccessIsRefused(config: UserConfig?) {
        #expect((OctopusCommunityAccessDeniedReason(userConfig: config) != nil)
                == (config?.canAccessCommunity == false))
    }

    @Test func aRefusalWithoutReasonIsUnknown() {
        let reason = OctopusCommunityAccessDeniedReason(
            userConfig: UserConfig(canAccessCommunity: false, accessDeniedMessage: "msg"))

        #expect(reason == .unknown)
    }

    @Test func theNewScreenMapsToItsPublicCase() {
        guard case .communityAccessDenied = OctopusEvent.Screen(from: .communityAccessDenied) else {
            Issue.record("Expected the community access denied screen")
            return
        }
    }
}
