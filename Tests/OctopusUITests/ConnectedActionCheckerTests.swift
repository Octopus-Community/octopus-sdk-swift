//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
import Foundation
@testable import OctopusUI
@testable import OctopusCore

/// Unit tests for `ConnectedActionChecker.decision(...)` — the pure gate that decides whether a user
/// action may proceed, and if not, what UI replaces it.
///
/// Regression focus (issue #307): on the *proceed* path (connected, config loaded, past the
/// strong-action guest gate and the nickname screen) a lingering connection error must NOT surface a
/// popup. Previously the branch raised `Connection.SSO.Error.Unknown` while still allowing the action,
/// producing a spurious "retrieve your data" alert on the first bridge-share post (the post succeeds).
struct ConnectedActionCheckerTests {
    private typealias Sut = ConnectedActionChecker

    private var ssoUnknown: Sut.Decision {
        .block(.error(.localizationKey("Connection.SSO.Error.Unknown")))
    }

    private func connected(configAvailable: Bool = true,
                           forceLogin: Bool = false,
                           isGuest: Bool = false,
                           hasConfirmedNickname: Bool = true,
                           nicknameLock: ProfileFieldLockState = .editable,
                           hasError: Bool = false) -> Sut.ConnectionDecisionState {
        .connected(communityConfigAvailable: configAvailable,
                   forceLoginOnStrongActions: forceLogin,
                   profileIsGuest: isGuest,
                   profileHasConfirmedNickname: hasConfirmedNickname,
                   nicknameLock: nicknameLock,
                   hasError: hasError)
    }

    // MARK: - Regression: spurious SSO error popup on the proceed path (#307)

    @Test func connectedWithLingeringError_stillProceeds_noPopup() {
        // The exact triad the popup used to key on: SSO + client user connected + a stored error,
        // while the action is allowed to proceed (nickname already confirmed).
        let decision = Sut.decision(
            magicLinkRequestActive: false,
            state: connected(hasConfirmedNickname: true, hasError: true),
            isSSO: true,
            clientUserConnected: true,
            action: .post)

        #expect(decision == .proceed)
    }

    @Test func connectedWithoutError_proceeds_sameAsWithError() {
        // Control: the healthy path already proceeded — the fix makes the error path behave identically.
        let decision = Sut.decision(
            magicLinkRequestActive: false,
            state: connected(hasConfirmedNickname: true, hasError: false),
            isSSO: true,
            clientUserConnected: true,
            action: .post)

        #expect(decision == .proceed)
    }

    // MARK: - Guarded branches still intact (lock the refactor)

    @Test func magicLinkPending_blocksWithLogin() {
        #expect(Sut.decision(magicLinkRequestActive: true, state: .notConnected,
                             isSSO: true, clientUserConnected: true, action: .post) == .block(.login))
    }

    @Test func notConnected_sso_clientConnected_blocksWithSSOError() {
        #expect(Sut.decision(magicLinkRequestActive: false, state: .notConnected,
                             isSSO: true, clientUserConnected: true, action: .post) == ssoUnknown)
    }

    @Test func notConnected_sso_clientNotConnected_requiresSSOLogin() {
        #expect(Sut.decision(magicLinkRequestActive: false, state: .notConnected,
                             isSSO: true, clientUserConnected: false, action: .post) == .requireSSOLogin)
    }

    @Test func notConnected_nonSSO_blocksWithLogin() {
        #expect(Sut.decision(magicLinkRequestActive: false, state: .notConnected,
                             isSSO: false, clientUserConnected: false, action: .post) == .block(.login))
    }

    @Test func connected_configMissing_blocksWithLoadConfig() {
        #expect(Sut.decision(magicLinkRequestActive: false, state: connected(configAvailable: false),
                             isSSO: true, clientUserConnected: true, action: .post) == .block(.loadConfig))
    }

    @Test func strongActionAsGuestWithForceLogin_sso_clientConnected_blocksWithSSOError() {
        #expect(Sut.decision(
            magicLinkRequestActive: false,
            state: connected(forceLogin: true, isGuest: true),
            isSSO: true, clientUserConnected: true, action: .post) == ssoUnknown)
    }

    @Test func strongActionAsGuestWithForceLogin_sso_clientNotConnected_requiresSSOLogin() {
        #expect(Sut.decision(
            magicLinkRequestActive: false,
            state: connected(forceLogin: true, isGuest: true),
            isSSO: true, clientUserConnected: false, action: .post) == .requireSSOLogin)
    }

    @Test func strongActionAsGuestWithForceLogin_nonSSO_blocksWithLogin() {
        #expect(Sut.decision(
            magicLinkRequestActive: false,
            state: connected(forceLogin: true, isGuest: true),
            isSSO: false, clientUserConnected: false, action: .post) == .block(.login))
    }

    @Test func editableNicknameNotConfirmed_blocksWithNicknameValidation() {
        #expect(Sut.decision(
            magicLinkRequestActive: false,
            state: connected(hasConfirmedNickname: false, nicknameLock: .editable),
            isSSO: true, clientUserConnected: true, action: .post) == .block(.validateNickname))
    }

    @Test func weakActionAsGuestWithForceLogin_proceeds() {
        // The strong-action gate only applies to strong actions; a reaction proceeds.
        #expect(Sut.decision(
            magicLinkRequestActive: false,
            state: connected(forceLogin: true, isGuest: true, hasError: true),
            isSSO: true, clientUserConnected: true, action: .reaction) == .proceed)
    }
}
