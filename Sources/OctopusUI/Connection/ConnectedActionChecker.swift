//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

enum UserAction {
    case post
    case comment
    case reply
    case reaction
    case vote
    case moderation
    case blockUser
    case viewOwnProfile

    var isStrong: Bool {
        switch self {
        case .post, .comment, .reply, .viewOwnProfile:
            return true
        case .reaction, .vote, .moderation, .blockUser:
            return false
        }
    }

    var needNicknameValidation: Bool {
        switch self {
        case .post, .comment, .reply:
            return true
        case .reaction, .vote, .moderation, .blockUser, .viewOwnProfile:
            return false
        }
    }

    /// The Core-level action type reported with the `octopus_driven_login` analytics event when this
    /// action is what triggered the login request.
    var drivenLoginAction: OctopusDrivenLoginAction {
        switch self {
        case .post: return .post
        case .comment: return .comment
        case .reply: return .reply
        case .reaction: return .reaction
        case .vote: return .vote
        case .moderation: return .moderation
        case .blockUser: return .blockUser
        case .viewOwnProfile: return .viewOwnProfile
        }
    }
}

enum ConnectedActionReplacement: Equatable {
    /// The nickname choice screen, which names the contribution it holds back.
    case validateNickname(UserAction)
    case loadConfig
//    case createProfile
    /// A failure worth retrying: the router shows it *and* re-runs the client-user exchange, which is how
    /// a transient one heals itself.
    ///
    /// ``decision(state:clientUserConnected:action:)`` returns it only when a client user is connected
    /// without a signed-in (non-guest) Octopus session, which is the one situation the exchange can repair.
    case error(DisplayableString)
    /// A ban, carrying the server's own wording. Kept apart from ``error`` because retrying is exactly
    /// what must not happen: no exchange lifts a ban, so re-running it only costs a round trip per tap.
    case banned(DisplayableString)
}

@MainActor
class ConnectedActionChecker {
    private let octopus: OctopusSDK

    init(octopus: OctopusSDK) {
        self.octopus = octopus
    }

    /// Whether an action must route through the nickname choice screen.
    ///
    /// A community-locked nickname (`read only` / `disabled`) is treated as already-confirmed:
    /// the confirmation screen is skipped for a field the user cannot edit, so the
    /// user posts directly with the auto-generated, non-editable nickname. Editable nicknames keep
    /// today's behaviour, so this is a strict no-op for every other community.
    ///
    /// A nickname the host app manages (see ``isNicknameAppManaged(octopus:isGuest:)``) is skipped for
    /// the same reason: the member cannot change it in the SDK, the host sets it. The profile merger only
    /// marks it confirmed when the host sends a nickname that differs from the stored one, so
    /// `hasConfirmedNickname` alone can stay `false` for such a member.
    nonisolated static func needsNicknameValidation(for action: UserAction,
                                                    hasConfirmedNickname: Bool,
                                                    nicknameLock: ProfileFieldLockState,
                                                    isNicknameAppManaged: Bool) -> Bool {
        action.needNicknameValidation && !hasConfirmedNickname && nicknameLock == .editable
            && !isNicknameAppManaged
    }

    /// Whether the host app owns the nickname of this member: the `isNicknameAppManaged` value every caller
    /// of `needsNicknameValidation` passes.
    ///
    /// Same rule as the profile edition and the picture of the nickname choice screen: the SSO
    /// configuration's `appManagedFields` only apply to a member signed in through the host app, so a guest,
    /// who has no host account, never has an app-managed nickname.
    static func isNicknameAppManaged(octopus: OctopusSDK, isGuest: Bool) -> Bool {
        isNicknameAppManaged(connectionMode: octopus.core.connectionRepository.connectionMode, isGuest: isGuest)
    }

    /// ``isNicknameAppManaged(octopus:isGuest:)`` on plain values, so the guest rule is unit-testable.
    nonisolated static func isNicknameAppManaged(connectionMode: OctopusCore.ConnectionMode, isGuest: Bool) -> Bool {
        guard !isGuest, case let .sso(configuration) = connectionMode else { return false }
        return configuration.appManagedFields.contains(.nickname)
    }

    /// Resolved connection facts fed to ``decision(state:clientUserConnected:action:)``.
    /// Keeping the decision inputs as plain values (instead of reading `octopus.core` inline) makes the
    /// full guest / client user / error matrix unit-testable without a live SDK.
    ///
    /// `hasError` is any lingering connection error, deliberately ignored on the proceed path (see
    /// ``decision(state:clientUserConnected:action:)``).
    /// `isNicknameAppManaged` is ``isNicknameAppManaged(octopus:isGuest:)`` for the connected profile.
    /// `userBannedMessage` is the narrower subset the blocking branches do care about: the server's own
    /// words for why this client user has no Octopus session.
    enum ConnectionDecisionState: Equatable {
        case notConnected(userBannedMessage: String?)
        case connected(communityConfigAvailable: Bool,
                       forceLoginOnStrongActions: Bool,
                       profileIsGuest: Bool,
                       profileHasConfirmedNickname: Bool,
                       nicknameLock: ProfileFieldLockState,
                       isNicknameAppManaged: Bool,
                       hasError: Bool,
                       userBannedMessage: String?)
    }

    /// What ``ensureConnected(action:actionWhenNotConnected:)`` should do. The caller performs the
    /// side effects (setting the replacement binding, or calling `config.loginRequired()`).
    enum Decision: Equatable {
        /// The action is allowed to proceed (`ensureConnected` returns `true`).
        case proceed
        /// The action is blocked and replaced by the given UI (`ensureConnected` returns `false`).
        case block(ConnectedActionReplacement)
        /// The action is blocked and the host's SSO login must be requested (`ensureConnected` returns `false`).
        case requireSSOLogin
    }

    /// Pure, side-effect-free decision for ``ensureConnected(action:actionWhenNotConnected:)``.
    ///
    /// Notably, on the *proceed* path (connected, config loaded, past the strong-action guest gate and
    /// the nickname screen) it returns ``Decision/proceed`` regardless of a lingering connection error:
    /// previously this branch raised `Connection.SSO.Error.Unknown` while still allowing the action,
    /// which surfaced a spurious "retrieve your data" popup on the first post even though the post
    /// succeeded (the stored `lastConnectionError` self-heals via the retry the alert itself triggers).
    /// This aligns iOS with Android, whose connected state carries no error field.
    nonisolated static func decision(state: ConnectionDecisionState,
                                     clientUserConnected: Bool,
                                     action: UserAction) -> Decision {
        switch state {
        case let .notConnected(userBannedMessage):
            if let banned = banBlock(userBannedMessage) { return banned }
            return clientUserConnected
                ? .block(.error(.localizationKey("Connection.SSO.Error.Unknown")))
                : .requireSSOLogin
        case let .connected(communityConfigAvailable, forceLoginOnStrongActions, profileIsGuest,
                            profileHasConfirmedNickname, nicknameLock, isNicknameAppManaged, _,
                            userBannedMessage):
            guard communityConfigAvailable else { return .block(.loadConfig) }
            // Ahead of the force-login gate, not inside it. A ban and a forced login are unrelated
            // questions — one says this person may not contribute at all, the other says guests must
            // sign in first — and reading the ban only inside that gate let a community that does not
            // force login skip it: the banned user reached the nickname screen, or published outright.
            // What they published under is the guest session, a different Octopus user from the banned
            // one, so the server had no reason to refuse it and the SDK routed around its own ban.
            if action.isStrong, let banned = banBlock(userBannedMessage) { return banned }
            if action.isStrong, profileIsGuest, forceLoginOnStrongActions {
                return clientUserConnected
                    ? .block(.error(.localizationKey("Connection.SSO.Error.Unknown")))
                    : .requireSSOLogin
            }
            if needsNicknameValidation(for: action,
                                       hasConfirmedNickname: profileHasConfirmedNickname,
                                       nicknameLock: nicknameLock,
                                       isNicknameAppManaged: isNicknameAppManaged) {
                return .block(.validateNickname(action))
            }
            return .proceed
        }
    }

    /// The answer a ban forces, ahead of every other one this gate could give, or `nil` when there is no
    /// ban to report.
    ///
    /// It outranks the two alternatives on purpose. Asking to try again in a few moments is right for the
    /// passing failures — the exchange timed out, the server hiccuped — but waiting changes nothing here.
    /// Sending the user to a login screen, the host's or the SDK's, is worse: no sign-in lifts a ban, and
    /// a banned guest has no client user to sign in as, so the screen is a dead end. The backend already
    /// said why, in the user's own language; that is what gets shown.
    nonisolated private static func banBlock(_ userBannedMessage: String?) -> Decision? {
        userBannedMessage.map { .block(.banned(.localizedString($0))) }
    }

    /// The profile ``ensureConnected(action:actionWhenNotConnected:)`` decides on, or `nil` when not connected.
    /// A contribution held for the nickname choice is held for this profile.
    static func connectedProfile(octopus: OctopusSDK) -> CurrentUserProfile? {
        guard case let .connected(user, _) = octopus.core.connectionRepository.connectionState else { return nil }
        return profile(of: user, octopus: octopus)
    }

    private static func profile(of user: User, octopus: OctopusSDK) -> CurrentUserProfile {
        // use the profile from profileRepository because it is updated quicker than the profile in the User
        octopus.core.profileRepository.profile ?? user.profile
    }

    func ensureConnected(action: UserAction, actionWhenNotConnected: Binding<ConnectedActionReplacement?>) -> Bool {
        let connectionRepository = octopus.core.connectionRepository

        let connectionState = connectionRepository.connectionState
        let userBannedMessage = connectionState.userBannedMessage
        let state: ConnectionDecisionState
        switch connectionState {
        case .notConnected:
            state = .notConnected(userBannedMessage: userBannedMessage)
        case let .connected(user, error):
            let profile = Self.profile(of: user, octopus: octopus)
            let communityConfig = octopus.core.configRepository.communityConfig
            state = .connected(
                communityConfigAvailable: communityConfig != nil,
                forceLoginOnStrongActions: communityConfig?.forceLoginOnStrongActions ?? false,
                profileIsGuest: profile.isGuest,
                profileHasConfirmedNickname: profile.hasConfirmedNickname,
                nicknameLock: communityConfig?.profileFieldsLock.nickname ?? .editable,
                isNicknameAppManaged: Self.isNicknameAppManaged(octopus: octopus, isGuest: profile.isGuest),
                hasError: error != nil,
                userBannedMessage: userBannedMessage)
        }

        switch Self.decision(state: state,
                             clientUserConnected: connectionRepository.clientUserConnected,
                             action: action) {
        case .proceed:
            return true
        case let .block(replacement):
            actionWhenNotConnected.wrappedValue = replacement
            return false
        case .requireSSOLogin:
            // octopus_driven_login: this action is what triggered the host's login prompt.
            octopus.core.octopusDrivenLoginMonitor.notifyLoginRequested(action: action.drivenLoginAction)
            switch connectionRepository.connectionMode {
            case let .sso(config): config.loginRequired()
            }
            return false
        }
    }
}
