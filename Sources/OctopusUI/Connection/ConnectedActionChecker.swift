//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

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

    func ensureConnected(action: UserAction, actionWhenNotConnected: Binding<ConnectedActionReplacement?>) -> Bool {
        guard octopus.core.connectionRepository.magicLinkRequest == nil else {
            actionWhenNotConnected.wrappedValue = .login
            return false
        }
        switch octopus.core.connectionRepository.connectionState {
        case .notConnected:
            if case let .sso(config) = octopus.core.connectionRepository.connectionMode {
                if octopus.core.connectionRepository.clientUserConnected {
                    actionWhenNotConnected.wrappedValue = .error(.localizationKey("Connection.SSO.Error.Unknown"))
                } else {
                    config.loginRequired()
                }
            } else {
                actionWhenNotConnected.wrappedValue = .login
            }
        case let .connected(user, error):
            // use the profile from profileRepository because it is updated quicker than the profile in the User
            let profile = octopus.core.profileRepository.profile ?? user.profile

            guard let communityConfig = octopus.core.configRepository.communityConfig else {
                actionWhenNotConnected.wrappedValue = .loadConfig
                return false
            }
            let forceLoginOnStrongActions = communityConfig.forceLoginOnStrongActions
            if action.isStrong, profile.isGuest, forceLoginOnStrongActions {
                if case let .sso(config) = octopus.core.connectionRepository.connectionMode {
                    if octopus.core.connectionRepository.clientUserConnected {
                        actionWhenNotConnected.wrappedValue = .error(.localizationKey("Connection.SSO.Error.Unknown"))
                    } else {
                        config.loginRequired()
                    }
                } else {
                    actionWhenNotConnected.wrappedValue = .login
                }
            } else if action.needNicknameValidation && !profile.hasConfirmedNickname {
                actionWhenNotConnected.wrappedValue = .validateNickname
            } else {
                if error != nil {
                    //TODO Djavan
//                    octopus.core.connectionRepository.connectAsync()
                }
                return true
            }
        }
        return false
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
