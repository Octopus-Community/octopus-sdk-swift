//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusUI

/// Unit-tests for `isOtherUserActivity`, the activity-screen self/other routing that backs Unified
/// Profile (OCT-1374, ported from Android's `IsOtherUserActivityTest`). The connected user's own
/// activity (`nil` id, or their own id) shows the two-tab activity view; any other member's id shows
/// the single-tab posts view.
@Suite
struct IsOtherUserActivityTests {
    @Test func nullRequestedIdIsTheConnectedUser() {
        #expect(!isOtherUserActivity(requestedProfileId: nil, connectedProfileId: "me"))
    }

    @Test func requestedIdEqualToTheConnectedIdIsTheConnectedUser() {
        #expect(!isOtherUserActivity(requestedProfileId: "me", connectedProfileId: "me"))
    }

    @Test func aDifferentRequestedIdIsAnotherUser() {
        #expect(isOtherUserActivity(requestedProfileId: "other", connectedProfileId: "me"))
    }

    @Test func aRequestedIdWithAnUnknownConnectedUserIsTreatedAsAnotherUser() {
        #expect(isOtherUserActivity(requestedProfileId: "other", connectedProfileId: nil))
    }
}

/// Unit-tests for `resolveActivityMode`, the activity-screen mode routing for Unified Profile
/// (OCT-1374, ported from Android's `ResolveActivityModeTest`). It runs after the (possibly async)
/// `clientUserId` → Octopus-id lookup settles and must never fall back to the connected user's own
/// activity when a specific member was requested but could not be resolved.
@Suite
struct ActivityModeTests {
    @Test func noIdRequestedIsTheConnectedUser() {
        #expect(
            resolveActivityMode(profileId: nil, clientUserId: nil, requestedUserId: nil,
                                connectedUserId: "me")
                == .connectedUser)
    }

    @Test func plainProfileIdThatDiffersFromTheConnectedUserIsAnotherUser() {
        #expect(
            resolveActivityMode(profileId: "other", clientUserId: nil, requestedUserId: "other",
                                connectedUserId: "me")
                == .resolved(profileId: "other"))
    }

    @Test func plainProfileIdEqualToTheConnectedIdIsTheConnectedUser() {
        #expect(
            resolveActivityMode(profileId: "me", clientUserId: nil, requestedUserId: "me",
                                connectedUserId: "me")
                == .connectedUser)
    }

    @Test func resolvedClientUserIdThatDiffersFromTheConnectedUserIsAnotherUser() {
        #expect(
            resolveActivityMode(profileId: nil, clientUserId: "client-42", requestedUserId: "other",
                                connectedUserId: "me")
                == .resolved(profileId: "other"))
    }

    @Test func clientUserIdResolvingToTheConnectedUserIsTheConnectedUser() {
        // A host that opens the activity for its own clientUserId is treated as the connected user
        // (same contract as passing the connected user's own Octopus id).
        #expect(
            resolveActivityMode(profileId: nil, clientUserId: "client-me", requestedUserId: "me",
                                connectedUserId: "me")
                == .connectedUser)
    }

    @Test func unresolvedClientUserIdIsLookupFailedNeverTheConnectedUser() {
        #expect(
            resolveActivityMode(profileId: nil, clientUserId: "stale-or-unknown", requestedUserId: nil,
                                connectedUserId: "me")
                == .lookupFailed)
    }

    @Test func unresolvedClientUserIdWithNoConnectedUserIsStillLookupFailed() {
        #expect(
            resolveActivityMode(profileId: nil, clientUserId: "stale-or-unknown", requestedUserId: nil,
                                connectedUserId: nil)
                == .lookupFailed)
    }
}
