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
}

enum ConnectedActionReplacement: Equatable {
    case login
    case validateNickname
    case loadConfig
//    case createProfile
    case error(DisplayableString)
}

@MainActor
class ConnectedActionChecker {
    private let octopus: OctopusSDK

    init(octopus: OctopusSDK) {
        self.octopus = octopus
    }

    /// Whether an action must route through the first-post nickname-confirmation screen.
    ///
    /// A community-locked nickname (`read only` / `disabled`) is treated as already-confirmed
    /// (OCT-1487, Q5): the confirmation screen is skipped for a field the user cannot edit, so the
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
    enum ConnectionDecisionState: Equatable {
        case notConnected
        case connected(communityConfigAvailable: Bool,
                       forceLoginOnStrongActions: Bool,
                       profileIsGuest: Bool,
                       profileHasConfirmedNickname: Bool,
                       nicknameLock: ProfileFieldLockState,
                       hasError: Bool)
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
        case .notConnected:
            guard isSSO else { return .block(.login) }
            return clientUserConnected
                ? .block(.error(.localizationKey("Connection.SSO.Error.Unknown")))
                : .requireSSOLogin
        case let .connected(communityConfigAvailable, forceLoginOnStrongActions, profileIsGuest,
                            profileHasConfirmedNickname, nicknameLock, _):
            guard communityConfigAvailable else { return .block(.loadConfig) }
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

    func ensureConnected(action: UserAction, actionWhenNotConnected: Binding<ConnectedActionReplacement?>) -> Bool {
        let connectionRepository = octopus.core.connectionRepository
        let isSSO: Bool = if case .sso = connectionRepository.connectionMode { true } else { false }

        let state: ConnectionDecisionState
        switch connectionRepository.connectionState {
        case .notConnected:
            state = .notConnected
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
                hasError: error != nil)
        }

        switch Self.decision(magicLinkRequestActive: connectionRepository.magicLinkRequest != nil,
                             state: state, isSSO: isSSO,
                             clientUserConnected: connectionRepository.clientUserConnected,
                             action: action) {
        case .proceed:
            return true
        case let .block(replacement):
            actionWhenNotConnected.wrappedValue = replacement
            return false
        case .requireSSOLogin:
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
