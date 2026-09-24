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
                           hasError: Bool = false,
                           userBannedMessage: String? = nil) -> Sut.ConnectionDecisionState {
        .connected(communityConfigAvailable: configAvailable,
                   forceLoginOnStrongActions: forceLogin,
                   profileIsGuest: isGuest,
                   profileHasConfirmedNickname: hasConfirmedNickname,
                   nicknameLock: nicknameLock,
                   hasError: hasError,
                   userBannedMessage: userBannedMessage)
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

    // MARK: - A ban is explained by the server, not by the generic "try again later"

    @Test func notConnected_sso_clientConnected_banned_showsServerMessage() {
        // The blocked branch used to answer "We are trying to retrieve your data. Please try again in a
        // few moments." to a banned user — an invitation to retry what can never succeed, hiding the
        // reason the backend already sent, already localized.
        #expect(Sut.decision(
            magicLinkRequestActive: false,
            state: .notConnected(userBannedMessage: "Your account has been blocked until 2026-10-01."),
            isSSO: true, clientUserConnected: true, action: .post)
                == .block(.banned(.localizedString("Your account has been blocked until 2026-10-01."))))
    }

    /// The path a banned SSO user actually lands on: a guest session is already up from the frictionless
    /// connection made at launch, the client-token exchange is then refused and leaves its ban on that
    /// state, and the first strong action hits the force-login gate.
    @Test func strongActionAsGuestWithForceLogin_sso_clientConnected_banned_showsServerMessage() {
        #expect(Sut.decision(
            magicLinkRequestActive: false,
            state: connected(forceLogin: true, isGuest: true, hasError: true,
                             userBannedMessage: "Your account has been blocked."),
            isSSO: true, clientUserConnected: true, action: .post)
                == .block(.banned(.localizedString("Your account has been blocked."))))
    }

    /// A guest can be banned without any client user existing — the backend refuses the guest exchange
    /// itself, which leaves no session at all. Reading `clientUserConnected` first sent that user to the
    /// host's login screen, a dead end: there is no account to sign into, and no sign-in lifts a ban.
    @Test func banned_withoutClientUser_showsServerMessageRatherThanLogin() {
        #expect(Sut.decision(
            magicLinkRequestActive: false,
            state: .notConnected(userBannedMessage: "Your account has been blocked."),
            isSSO: true, clientUserConnected: false, action: .post)
                == .block(.banned(.localizedString("Your account has been blocked."))))
    }

    /// Same on a weak action: a like is not gated by the force-login branch, so before the fix it fell
    /// straight through to `requireSSOLogin` too.
    @Test func banned_withoutClientUser_weakAction_showsServerMessage() {
        #expect(Sut.decision(
            magicLinkRequestActive: false,
            state: .notConnected(userBannedMessage: "Your account has been blocked."),
            isSSO: true, clientUserConnected: false, action: .reaction)
                == .block(.banned(.localizedString("Your account has been blocked."))))
    }

    /// The ban used to be consulted only *inside* the force-login gate, so a community that does not
    /// force login on strong actions skipped it entirely: a banned user fell through to the nickname
    /// screen, or straight to `proceed` and actually published. The guest session they publish under is
    /// a different Octopus user from the banned one, so the server had no reason to refuse it — the SDK
    /// was routing its way around the ban.
    @Test(arguments: [true, false])
    func banned_strongAction_blocksWhateverTheForceLoginSetting(nicknameConfirmed: Bool) {
        #expect(Sut.decision(
            magicLinkRequestActive: false,
            state: connected(forceLogin: false, isGuest: true, hasConfirmedNickname: nicknameConfirmed,
                             hasError: true, userBannedMessage: "You are banned."),
            isSSO: true, clientUserConnected: true, action: .post)
                == .block(.banned(.localizedString("You are banned."))))
    }

    /// A ban on a logged-in user is just as final as one on a guest.
    @Test func banned_nonGuest_strongAction_blocks() {
        #expect(Sut.decision(
            magicLinkRequestActive: false,
            state: connected(forceLogin: false, isGuest: false, hasError: true,
                             userBannedMessage: "You are banned."),
            isSSO: true, clientUserConnected: true, action: .post)
                == .block(.banned(.localizedString("You are banned."))))
    }

    /// Deliberately left alone: a like stays allowed on a working guest session. Gating it would raise a
    /// modal on a tap people repeat while scrolling, and the server refuses the reaction on its own
    /// anyway. See also `weakActionAsGuestWithForceLogin_proceeds`.
    @Test func banned_weakAction_stillProceeds() {
        #expect(Sut.decision(
            magicLinkRequestActive: false,
            state: connected(forceLogin: false, isGuest: true, hasError: true,
                             userBannedMessage: "You are banned."),
            isSSO: true, clientUserConnected: true, action: .reaction) == .proceed)
    }

    /// The #307 guard, restated against this change: a lingering error that is *not* a ban must still let
    /// the action through, which is what keeps `banBlock` keyed on the message rather than on `hasError`.
    @Test func lingeringNonBanError_strongAction_stillProceeds() {
        #expect(Sut.decision(
            magicLinkRequestActive: false,
            state: connected(forceLogin: false, isGuest: false, hasError: true, userBannedMessage: nil),
            isSSO: true, clientUserConnected: true, action: .post) == .proceed)
    }

    /// The SDK's own magic-link screen is just as much of a dead end for a banned guest.
    ///
    /// The case matters as much as the message: it must be `.banned`, never `.error`. The router answers
    /// `.error` by re-running `linkClientUserToOctopusUser`, and in magic-link mode that call is a
    /// `preconditionFailure` — so returning `.error` here would trap the host app.
    @Test func banned_nonSSO_showsServerMessageRatherThanLogin() {
        #expect(Sut.decision(
            magicLinkRequestActive: false,
            state: .notConnected(userBannedMessage: "Your account has been blocked."),
            isSSO: false, clientUserConnected: false, action: .post)
                == .block(.banned(.localizedString("Your account has been blocked."))))
    }

    // MARK: - Guarded branches still intact (lock the refactor)

    @Test func magicLinkPending_blocksWithLogin() {
        #expect(Sut.decision(magicLinkRequestActive: true, state: .notConnected(userBannedMessage: nil),
                             isSSO: true, clientUserConnected: true, action: .post) == .block(.login))
    }

    @Test func notConnected_sso_clientConnected_blocksWithSSOError() {
        #expect(Sut.decision(magicLinkRequestActive: false, state: .notConnected(userBannedMessage: nil),
                             isSSO: true, clientUserConnected: true, action: .post) == ssoUnknown)
    }

    @Test func notConnected_sso_clientNotConnected_requiresSSOLogin() {
        #expect(Sut.decision(magicLinkRequestActive: false, state: .notConnected(userBannedMessage: nil),
                             isSSO: true, clientUserConnected: false, action: .post) == .requireSSOLogin)
    }

    @Test func notConnected_nonSSO_blocksWithLogin() {
        #expect(Sut.decision(magicLinkRequestActive: false, state: .notConnected(userBannedMessage: nil),
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
