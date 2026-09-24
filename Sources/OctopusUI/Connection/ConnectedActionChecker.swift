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
    case login
    case validateNickname
    case loadConfig
//    case createProfile
    /// A failure worth retrying: the router shows it *and* re-runs the client-user exchange, which is how
    /// a transient one heals itself.
    ///
    /// Only meaningful in SSO — there is no client user to link otherwise — and ``decision(magicLinkRequestActive:state:isSSO:clientUserConnected:action:)``
    /// returns it only behind an `isSSO` check. That is a convention, not a guarantee, so the router
    /// re-checks the connection mode before acting on it rather than trusting this to hold.
    case error(DisplayableString)
    /// A ban, carrying the server's own wording. Kept apart from ``error`` because retrying is exactly
    /// what must not happen: no exchange lifts a ban, so re-running it only costs a round trip per tap —
    /// and in magic-link mode it would call into `linkClientUserToOctopusUser`, whose implementation there
    /// is a `preconditionFailure`.
    case banned(DisplayableString)
}

@MainActor
class ConnectedActionChecker {
    private let octopus: OctopusSDK

    init(octopus: OctopusSDK) {
        self.octopus = octopus
    }

    /// Whether an action must route through the first-post nickname-confirmation screen.
    ///
    /// A community-locked nickname (`read only` / `disabled`) is treated as already-confirmed:
    /// the confirmation screen is skipped for a field the user cannot edit, so the
    /// user posts directly with the auto-generated, non-editable nickname. Editable nicknames keep
    /// today's behaviour, so this is a strict no-op for every other community.
    nonisolated static func needsNicknameValidation(for action: UserAction,
                                                    hasConfirmedNickname: Bool,
                                                    nicknameLock: ProfileFieldLockState) -> Bool {
        action.needNicknameValidation && !hasConfirmedNickname && nicknameLock == .editable
    }

    /// Resolved connection facts fed to ``decision(magicLinkRequestActive:state:isSSO:clientUserConnected:action:)``.
    /// Keeping the decision inputs as plain values (instead of reading `octopus.core` inline) makes the
    /// full guest / SSO / error matrix unit-testable without a live SDK.
    ///
    /// `hasError` is any lingering connection error, deliberately ignored on the proceed path (see
    /// ``decision(magicLinkRequestActive:state:isSSO:clientUserConnected:action:)``).
    /// `userBannedMessage` is the narrower subset the blocking branches do care about: the server's own
    /// words for why this client user has no Octopus session.
    enum ConnectionDecisionState: Equatable {
        case notConnected(userBannedMessage: String?)
        case connected(communityConfigAvailable: Bool,
                       forceLoginOnStrongActions: Bool,
                       profileIsGuest: Bool,
                       profileHasConfirmedNickname: Bool,
                       nicknameLock: ProfileFieldLockState,
                       hasError: Bool,
                       userBannedMessage: String?)
    }

    /// What ``ensureConnected(action:actionWhenNotConnected:)`` should do. The caller performs the
    /// side effects (setting the replacement binding, or calling `config.loginRequired()` in SSO).
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
    /// This aligns iOS with Android, whose connected state carries no error field (issue #307).
    nonisolated static func decision(magicLinkRequestActive: Bool,
                                     state: ConnectionDecisionState,
                                     isSSO: Bool,
                                     clientUserConnected: Bool,
                                     action: UserAction) -> Decision {
        guard !magicLinkRequestActive else { return .block(.login) }

        switch state {
        case let .notConnected(userBannedMessage):
            if let banned = banBlock(userBannedMessage) { return banned }
            guard isSSO else { return .block(.login) }
            return clientUserConnected
                ? .block(.error(.localizationKey("Connection.SSO.Error.Unknown")))
                : .requireSSOLogin
        case let .connected(communityConfigAvailable, forceLoginOnStrongActions, profileIsGuest,
                            profileHasConfirmedNickname, nicknameLock, _, userBannedMessage):
            guard communityConfigAvailable else { return .block(.loadConfig) }
            // Ahead of the force-login gate, not inside it. A ban and a forced login are unrelated
            // questions — one says this person may not contribute at all, the other says guests must
            // sign in first — and reading the ban only inside that gate let a community that does not
            // force login skip it: the banned user reached the nickname screen, or published outright.
            // What they published under is the guest session, a different Octopus user from the banned
            // one, so the server had no reason to refuse it and the SDK routed around its own ban.
            if action.isStrong, let banned = banBlock(userBannedMessage) { return banned }
            if action.isStrong, profileIsGuest, forceLoginOnStrongActions {
                guard isSSO else { return .block(.login) }
                return clientUserConnected
                    ? .block(.error(.localizationKey("Connection.SSO.Error.Unknown")))
                    : .requireSSOLogin
            }
            if needsNicknameValidation(for: action,
                                       hasConfirmedNickname: profileHasConfirmedNickname,
                                       nicknameLock: nicknameLock) {
                return .block(.validateNickname)
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

    func ensureConnected(action: UserAction, actionWhenNotConnected: Binding<ConnectedActionReplacement?>) -> Bool {
        let connectionRepository = octopus.core.connectionRepository
        let isSSO: Bool = if case .sso = connectionRepository.connectionMode { true } else { false }

        let connectionState = connectionRepository.connectionState
        let userBannedMessage = connectionState.userBannedMessage
        let state: ConnectionDecisionState
        switch connectionState {
        case .notConnected:
            state = .notConnected(userBannedMessage: userBannedMessage)
        case let .connected(user, error):
            // use the profile from profileRepository because it is updated quicker than the profile in the User
            let profile = octopus.core.profileRepository.profile ?? user.profile
            let communityConfig = octopus.core.configRepository.communityConfig
            state = .connected(
                communityConfigAvailable: communityConfig != nil,
                forceLoginOnStrongActions: communityConfig?.forceLoginOnStrongActions ?? false,
                profileIsGuest: profile.isGuest,
                profileHasConfirmedNickname: profile.hasConfirmedNickname,
                nicknameLock: communityConfig?.profileFieldsLock.nickname ?? .editable,
                hasError: error != nil,
                userBannedMessage: userBannedMessage)
        }

        let magicLinkActive = connectionRepository.magicLinkRequest != nil
        switch Self.decision(magicLinkRequestActive: magicLinkActive,
                             state: state, isSSO: isSSO,
                             clientUserConnected: connectionRepository.clientUserConnected,
                             action: action) {
        case .proceed:
            return true
        case let .block(replacement):
            // octopus_driven_login (#315): report when this action is what triggered a login prompt.
            // A `.login` replacement is a login drive on the non-SSO / magic-link-login paths — but not
            // when it merely reflects a pending magic-link request (which was not caused by this action).
            if replacement == .login, !magicLinkActive {
                octopus.core.octopusDrivenLoginMonitor.notifyLoginRequested(action: action.drivenLoginAction)
            }
            actionWhenNotConnected.wrappedValue = replacement
            return false
        case .requireSSOLogin:
            octopus.core.octopusDrivenLoginMonitor.notifyLoginRequested(action: action.drivenLoginAction)
            if case let .sso(config) = connectionRepository.connectionMode {
                config.loginRequired()
            }
            return false
        }
    }

//    func ensureConnected(actionWhenNotConnected: Binding<ConnectedActionReplacement?>) -> Bool {
//        guard octopus.core.connectionRepository.magicLinkRequest == nil else {
//            actionWhenNotConnected.wrappedValue = .login
//            return false
//        }
//        switch octopus.core.connectionRepository.connectionState {
//        case .notConnected/*, .magicLinkSent*/: // TODO Djavan: utiliser connectionRepository.magicLinkRequest
//            if case let .sso(config) = octopus.core.connectionRepository.connectionMode {
//                config.loginRequired()
//            } else {
//                actionWhenNotConnected.wrappedValue = .login
//            }
////        case let .clientConnected(_, error):
////            switch error {
////            case let .detailedErrors(errors):
////                if let error = errors.first(where: { $0.reason == .userBanned }) {
////                    actionWhenNotConnected.wrappedValue = .ssoError(.localizedString(error.message))
////                } else {
////                    fallthrough
////                }
////            default:
////                actionWhenNotConnected.wrappedValue = .ssoError(.localizationKey("Connection.SSO.Error.Unknown"))
////            }
////        case .profileCreationRequired:
////            actionWhenNotConnected.wrappedValue = .createProfile
//        case .connected:
//            return true
//        }
//        return false
//    }
}
