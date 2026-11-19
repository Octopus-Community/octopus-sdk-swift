//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import Octopus
import OctopusCore
@testable import OctopusUI

/// The `.profile` initial screen: which profile view it opens, how a client user id is resolved, and what the
/// deprecated `OctopusProfileScreen` opens.
@MainActor
struct ProfileInitialScreenTests {

    private struct LookupError: Error {}

    // MARK: - Which profile view

    @Test func currentUserOpensTheConnectedUserProfile() {
        #expect(ProfileSummarySource(OctopusInitialScreen.ProfileScreenInfo.currentUser.source) == nil)
    }

    @Test func clientUserIdOpensAnotherMemberProfileAfterALookup() {
        let info = OctopusInitialScreen.ProfileScreenInfo(clientUserId: "client-1")
        #expect(ProfileSummarySource(info.source) == .clientUserId("client-1"))
    }

    @Test func profileIdOpensAnotherMemberProfileDirectly() {
        let info = OctopusInitialScreen.ProfileScreenInfo(profileId: "profile-1")
        #expect(ProfileSummarySource(info.source) == .profileId("profile-1"))
    }

    // MARK: - Lookup of a client user id

    @Test func foundClientUserIdResolvesToTheMember() async {
        var askedId: String?
        let target = await resolveProfileSummaryTarget(clientUserId: "client-1") {
            askedId = $0
            return "profile-1"
        }
        #expect(askedId == "client-1")
        #expect(target == .resolved(profileId: "profile-1"))
    }

    /// An unknown id, or a community that does not expose client user ids: never another member's profile.
    @Test func unknownClientUserIdFailsWithTheNeutralState() async {
        let target = await resolveProfileSummaryTarget(clientUserId: "client-1") { _ in nil }
        #expect(target == .lookupFailed(.other))
    }

    @Test func lookupWithoutNetworkFailsWithTheNoNetworkState() async {
        let target = await resolveProfileSummaryTarget(clientUserId: "client-1") { _ in
            throw ServerCallError.noNetwork
        }
        #expect(target == .lookupFailed(.noNetwork))
    }

    @Test func lookupErrorFailsWithTheNeutralState() async {
        let target = await resolveProfileSummaryTarget(clientUserId: "client-1") { _ in throw LookupError() }
        #expect(target == .lookupFailed(.other))
    }

    // MARK: - Deprecated OctopusProfileScreen

    @Test func deprecatedProfileScreenWithoutIdOpensTheConnectedUserProfile() throws {
        guard case let .profile(info) = profileInitialScreen(clientUserId: nil) else {
            Issue.record("Expected the profile initial screen")
            return
        }
        #expect(info.source == .currentUser)
    }

    @Test func deprecatedProfileScreenWithIdOpensThatMember() throws {
        guard case let .profile(info) = profileInitialScreen(clientUserId: "client-1") else {
            Issue.record("Expected the profile initial screen")
            return
        }
        #expect(info.source == .clientUserId("client-1"))
    }
}
