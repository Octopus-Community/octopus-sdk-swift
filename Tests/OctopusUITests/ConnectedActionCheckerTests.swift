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
/// Regression focus: on the *proceed* path (connected, config loaded, past the
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
                           isNicknameAppManaged: Bool = false,
                           hasError: Bool = false,
                           userBannedMessage: String? = nil) -> Sut.ConnectionDecisionState {
        .connected(communityConfigAvailable: configAvailable,
                   forceLoginOnStrongActions: forceLogin,
                   profileIsGuest: isGuest,
                   profileHasConfirmedNickname: hasConfirmedNickname,
                   nicknameLock: nicknameLock,
                   isNicknameAppManaged: isNicknameAppManaged,
                   hasError: hasError,
                   userBannedMessage: userBannedMessage)
    }

    // MARK: - Regression: spurious SSO error popup on the proceed path

    @Test func connectedWithLingeringError_stillProceeds_noPopup() {
        // The exact triad the popup used to key on: SSO + client user connected + a stored error,
        // while the action is allowed to proceed (nickname already confirmed).
        let decision = Sut.decision(
            state: connected(hasConfirmedNickname: true, hasError: true),
            clientUserConnected: true,
            action: .post)

        #expect(decision == .proceed)
    }

    @Test func connectedWithoutError_proceeds_sameAsWithError() {
        // Control: the healthy path already proceeded — the fix makes the error path behave identically.
        let decision = Sut.decision(
            state: connected(hasConfirmedNickname: true, hasError: false),
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
            state: .notConnected(userBannedMessage: "Your account has been blocked until 2026-10-01."),
            clientUserConnected: true, action: .post)
                == .block(.banned(.localizedString("Your account has been blocked until 2026-10-01."))))
    }

    /// The path a banned SSO user actually lands on: a guest session is already up from the frictionless
    /// connection made at launch, the client-token exchange is then refused and leaves its ban on that
    /// state, and the first strong action hits the force-login gate.
    @Test func strongActionAsGuestWithForceLogin_sso_clientConnected_banned_showsServerMessage() {
        #expect(Sut.decision(
            state: connected(forceLogin: true, isGuest: true, hasError: true,
                             userBannedMessage: "Your account has been blocked."),
            clientUserConnected: true, action: .post)
                == .block(.banned(.localizedString("Your account has been blocked."))))
    }

    /// A guest can be banned without any client user existing — the backend refuses the guest exchange
    /// itself, which leaves no session at all. Reading `clientUserConnected` first sent that user to the
    /// host's login screen, a dead end: there is no account to sign into, and no sign-in lifts a ban.
    @Test func banned_withoutClientUser_showsServerMessageRatherThanLogin() {
        #expect(Sut.decision(
            state: .notConnected(userBannedMessage: "Your account has been blocked."),
            clientUserConnected: false, action: .post)
                == .block(.banned(.localizedString("Your account has been blocked."))))
    }

    /// Same on a weak action: a like is not gated by the force-login branch, so before the fix it fell
    /// straight through to `requireSSOLogin` too.
    @Test func banned_withoutClientUser_weakAction_showsServerMessage() {
        #expect(Sut.decision(
            state: .notConnected(userBannedMessage: "Your account has been blocked."),
            clientUserConnected: false, action: .reaction)
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
            state: connected(forceLogin: false, isGuest: true, hasConfirmedNickname: nicknameConfirmed,
                             hasError: true, userBannedMessage: "You are banned."),
            clientUserConnected: true, action: .post)
                == .block(.banned(.localizedString("You are banned."))))
    }

    /// A ban on a logged-in user is just as final as one on a guest.
    @Test func banned_nonGuest_strongAction_blocks() {
        #expect(Sut.decision(
            state: connected(forceLogin: false, isGuest: false, hasError: true,
                             userBannedMessage: "You are banned."),
            clientUserConnected: true, action: .post)
                == .block(.banned(.localizedString("You are banned."))))
    }

    /// Deliberately left alone: a like stays allowed on a working guest session. Gating it would raise a
    /// modal on a tap people repeat while scrolling, and the server refuses the reaction on its own
    /// anyway. See also `weakActionAsGuestWithForceLogin_proceeds`.
    @Test func banned_weakAction_stillProceeds() {
        #expect(Sut.decision(
            state: connected(forceLogin: false, isGuest: true, hasError: true,
                             userBannedMessage: "You are banned."),
            clientUserConnected: true, action: .reaction) == .proceed)
    }

    /// The spurious-popup guard, restated against this change: a lingering error that is *not* a ban must
    /// still let the action through, which is what keeps `banBlock` keyed on the message rather than on `hasError`.
    @Test func lingeringNonBanError_strongAction_stillProceeds() {
        #expect(Sut.decision(
            state: connected(forceLogin: false, isGuest: false, hasError: true, userBannedMessage: nil),
            clientUserConnected: true, action: .post) == .proceed)
    }

    // MARK: - Guarded branches still intact (lock the refactor)

    @Test func notConnected_sso_clientConnected_blocksWithSSOError() {
        #expect(Sut.decision(state: .notConnected(userBannedMessage: nil),
                             clientUserConnected: true, action: .post) == ssoUnknown)
    }

    @Test func notConnected_sso_clientNotConnected_requiresSSOLogin() {
        #expect(Sut.decision(state: .notConnected(userBannedMessage: nil),
                             clientUserConnected: false, action: .post) == .requireSSOLogin)
    }

    @Test func connected_configMissing_blocksWithLoadConfig() {
        #expect(Sut.decision(state: connected(configAvailable: false),
                             clientUserConnected: true, action: .post) == .block(.loadConfig))
    }

    @Test func strongActionAsGuestWithForceLogin_sso_clientConnected_blocksWithSSOError() {
        #expect(Sut.decision(
            state: connected(forceLogin: true, isGuest: true),
            clientUserConnected: true, action: .post) == ssoUnknown)
    }

    @Test func strongActionAsGuestWithForceLogin_sso_clientNotConnected_requiresSSOLogin() {
        #expect(Sut.decision(
            state: connected(forceLogin: true, isGuest: true),
            clientUserConnected: false, action: .post) == .requireSSOLogin)
    }

    @Test(arguments: [UserAction.post, .comment, .reply])
    func editableNicknameNotConfirmed_blocksWithTheContribution(action: UserAction) {
        // The nickname choice screen names the contribution it holds back, so the block carries it.
        #expect(Sut.decision(
            state: connected(hasConfirmedNickname: false, nicknameLock: .editable),
            clientUserConnected: true, action: action) == .block(.validateNickname(action)))
    }

    // MARK: - A nickname managed by the host app is never chosen in the SDK

    /// The host app owns the nickname, so the member cannot edit it in the SDK. The profile merger marks
    /// it confirmed only when the host sends a nickname that differs from the stored one, so a member whose
    /// host nickname is the stored one (or absent) is still unconfirmed: that must not open the screen.
    @Test(arguments: [UserAction.post, .comment, .reply])
    func appManagedNickname_nonGuest_notConfirmed_proceeds(action: UserAction) {
        #expect(Sut.decision(
            state: connected(isGuest: false, hasConfirmedNickname: false, isNicknameAppManaged: true),
            clientUserConnected: true, action: action) == .proceed)
    }

    /// A nickname the host app does not manage keeps the screen for an unconfirmed member.
    @Test(arguments: [UserAction.post, .comment, .reply])
    func notAppManagedNickname_nonGuest_notConfirmed_stillBlocks(action: UserAction) {
        #expect(Sut.decision(
            state: connected(isGuest: false, hasConfirmedNickname: false, isNicknameAppManaged: false),
            clientUserConnected: true, action: action) == .block(.validateNickname(action)))
    }

    private func ssoMode(appManagedFields: Set<OctopusCore.ConnectionMode.SSOConfiguration.ProfileField>)
        -> OctopusCore.ConnectionMode {
        .sso(.init(appManagedFields: appManagedFields, loginRequired: { }, modifyUser: { _ in }))
    }

    @Test func nicknameInAppManagedFields_nonGuest_isAppManaged() {
        #expect(Sut.isNicknameAppManaged(connectionMode: ssoMode(appManagedFields: [.nickname]), isGuest: false))
        #expect(Sut.isNicknameAppManaged(connectionMode: ssoMode(appManagedFields: [.nickname, .picture, .bio]),
                                         isGuest: false))
    }

    @Test func nicknameNotInAppManagedFields_isNotAppManaged() {
        #expect(!Sut.isNicknameAppManaged(connectionMode: ssoMode(appManagedFields: []), isGuest: false))
        #expect(!Sut.isNicknameAppManaged(connectionMode: ssoMode(appManagedFields: [.picture, .bio]),
                                          isGuest: false))
    }

    /// Same rule as the profile edition and the picture of the nickname screen: the host app only manages
    /// the profile of a member it signed in, so a guest's nickname is never app-managed.
    @Test func nicknameInAppManagedFields_guest_isNotAppManaged() {
        #expect(!Sut.isNicknameAppManaged(connectionMode: ssoMode(appManagedFields: [.nickname]), isGuest: true))
    }

    /// The consequence for the gate: a guest who has not confirmed a nickname, in a community that does
    /// not force login, still chooses one before contributing, even when the host app manages nicknames.
    @Test func guest_appManagedNicknameConfig_notConfirmed_stillBlocks() {
        let isAppManaged = Sut.isNicknameAppManaged(connectionMode: ssoMode(appManagedFields: [.nickname]),
                                                    isGuest: true)
        #expect(Sut.decision(
            state: connected(forceLogin: false, isGuest: true, hasConfirmedNickname: false,
                             isNicknameAppManaged: isAppManaged),
            clientUserConnected: false, action: .post) == .block(.validateNickname(.post)))
    }

    @Test func weakActionAsGuestWithForceLogin_proceeds() {
        // The strong-action gate only applies to strong actions; a reaction proceeds.
        #expect(Sut.decision(
            state: connected(forceLogin: true, isGuest: true, hasError: true),
            clientUserConnected: true, action: .reaction) == .proceed)
    }
}
