//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

enum ConnectedActionReplacement: Equatable {
    case login
    case createProfile
    case ssoError(DisplayableString)
}

@MainActor
class ConnectedActionChecker {
    private let octopus: OctopusSDK
    init(octopus: OctopusSDK) {
        self.octopus = octopus
    }

    func ensureConnected(actionWhenNotConnected: Binding<ConnectedActionReplacement?>) -> Bool {
        switch octopus.core.connectionRepository.connectionState {
        case .notConnected, .magicLinkSent:
            if case let .sso(config) = octopus.core.connectionRepository.connectionMode {
                config.loginRequired()
            } else {
                actionWhenNotConnected.wrappedValue = .login
            }
        case let .clientConnected(_, error):
            switch error {
            case let .detailedErrors(errors):
                if let error = errors.first(where: { $0.reason == .userBanned }) {
                    actionWhenNotConnected.wrappedValue = .ssoError(.localizedString(error.message))
                } else {
                    fallthrough
                }
            default:
                actionWhenNotConnected.wrappedValue = .ssoError(.localizationKey("Connection.SSO.Error.Unknown"))
            }
        case .profileCreationRequired:
            actionWhenNotConnected.wrappedValue = .createProfile
        case .connected:
            return true
        }
        return false
    }
}
