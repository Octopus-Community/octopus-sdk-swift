//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
@testable import OctopusUI

/// When a contribution held back by `ensureConnected` is sent again, depending on why it was held back.
struct PendingSendReasonTests {
    private typealias Profile = PendingSendReason.Profile

    private func member(_ id: String = "p1", confirmed: Bool) -> Profile {
        Profile(id: id, isGuest: false, hasConfirmedNickname: confirmed)
    }

    private func guest(_ id: String = "p1", confirmed: Bool) -> Profile {
        Profile(id: id, isGuest: true, hasConfirmedNickname: confirmed)
    }

    // MARK: Holding

    @Test func heldForTheNicknameChoiceOfTheConnectedProfile() {
        #expect(PendingSendReason.held(isBlockedOnlyByNicknameChoice: true, profileId: "p1")
                == .nicknameChoice(profileId: "p1"))
    }

    @Test func heldForAConnectionOtherwise() {
        #expect(PendingSendReason.held(isBlockedOnlyByNicknameChoice: false, profileId: "p1") == .connection)
        #expect(PendingSendReason.held(isBlockedOnlyByNicknameChoice: false, profileId: nil) == .connection)
        #expect(PendingSendReason.held(isBlockedOnlyByNicknameChoice: true, profileId: nil) == .connection)
    }

    // MARK: Nickname choice

    @Test func nicknameChoiceWaitsForTheConfirmedNicknameOfItsMember() {
        let pending = PendingSendReason.nicknameChoice(profileId: "p1")
        #expect(pending.resolution(for: member(confirmed: false)) == .keepWaiting)
        #expect(pending.resolution(for: guest(confirmed: false)) == .keepWaiting)
        #expect(pending.resolution(for: member(confirmed: true)) == .send)
        #expect(pending.resolution(for: guest(confirmed: true)) == .send)
    }

    @Test func nicknameChoiceIsDroppedWithoutProfile() {
        #expect(PendingSendReason.nicknameChoice(profileId: "p1").resolution(for: nil) == .drop)
    }

    @Test func nicknameChoiceIsDroppedForAnotherMember() {
        let pending = PendingSendReason.nicknameChoice(profileId: "p1")
        #expect(pending.resolution(for: member("p2", confirmed: true)) == .drop)
        #expect(pending.resolution(for: member("p2", confirmed: false)) == .drop)
        #expect(pending.resolution(for: guest("p2", confirmed: true)) == .drop)
    }

    // MARK: Connection

    @Test func connectionWaitsForASignedInUserOrAConfirmedNickname() {
        #expect(PendingSendReason.connection.resolution(for: guest(confirmed: false)) == .keepWaiting)
        #expect(PendingSendReason.connection.resolution(for: member(confirmed: false)) == .send)
        #expect(PendingSendReason.connection.resolution(for: guest(confirmed: true)) == .send)
        #expect(PendingSendReason.connection.resolution(for: member(confirmed: true)) == .send)
    }

    /// A sign-in goes from the guest to the member through a moment without profile: the login wait survives it.
    @Test func connectionKeepsWaitingWithoutProfile() {
        #expect(PendingSendReason.connection.resolution(for: nil) == .keepWaiting)
    }

    @Test func connectionGoesOutOnceAnotherMemberSignsIn() {
        let pending = PendingSendReason.connection
        #expect(pending.resolution(for: guest("guest", confirmed: false)) == .keepWaiting)
        #expect(pending.resolution(for: nil) == .keepWaiting)
        #expect(pending.resolution(for: member("member", confirmed: false)) == .send)
    }

    // MARK: Config

    @Test func onlyAConnectionWaitResumesOnAConfigChange() {
        #expect(PendingSendReason.connection.resumesOnConfigChange)
        #expect(!PendingSendReason.nicknameChoice(profileId: "p1").resumesOnConfigChange)
    }
}
