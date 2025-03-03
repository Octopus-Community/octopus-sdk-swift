//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

/// The kind of connection
public enum ConnectionMode {
    /// Connection and user management is handled by OctopusSDK
    /// - Parameter deepLink: the deeplink trigger to re-open the app after magic link has been opened
    case octopus(deepLink: String?)
    /// You provide to OctopusSDK the user and their lifecycle are tight to their lifecycle in your app
    case sso(SSOConfiguration)
    
    /// Configuration of the SSO connection mode
    public struct SSOConfiguration {
        /// The field of a Profile
        public enum ProfileField: CaseIterable {
            /// Username
            case nickname
            /// Biography
            case bio
            /// Profile picture
            case picture
        }

        /// Set of profile fields that can only be updated by your app, not by Octopus.
        /// For example: if you `appManagedFields` contains `.nickname`, only your app will be able to update the
        /// user's nickname.
        let appManagedFields: Set<ProfileField>

        /// Block called when OctopusSDK needs a logged in user.
        /// When this block is called, you should start your login process.
        let loginRequired: () -> Void
        /// Block called when the user tries to modify some fields related to its profile.
        /// When this block is called, you should open the profile edition.
        let modifyUser: (ProfileField?) -> Void

        /// Constructor.
        /// - Parameters:
        ///   - appManagedFields: Set of fields that are "owned" by your app. An associated field cannot be
        ///                       updated by Octopus and is only updated by your app.
        ///   - loginRequired: Block called when OctopusSDK needs a logged in user.
        ///                    When this block is called, you should start your login process.
        ///   - modifyUser: Block called when the user tries to modify some fields related to its profile.
        ///                 When this block is called, you should open the profile edition.
        public init(appManagedFields: Set<ProfileField>,
             loginRequired: @escaping () -> Void,
             modifyUser: @escaping (ProfileField?) -> Void) {
            self.appManagedFields = appManagedFields
            self.loginRequired = loginRequired
            self.modifyUser = modifyUser
        }

        /// Constructor for a SSO Configuration with no app managed fields.
        ///
        /// - Parameters:
        ///   - loginRequired: Block called when OctopusSDK needs a logged in user.
        ///                    When this block is called, you should start your login process.
        public init(loginRequired: @escaping () -> Void) {
            self.appManagedFields = []
            self.loginRequired = loginRequired
            self.modifyUser = { _ in }
        }
    }
}

extension ConnectionMode.SSOConfiguration.ProfileField {
    init?(from value: OctopusCore.ConnectionMode.SSOConfiguration.ProfileField?) {
        guard let value else { return nil }
        self = switch value {
        case .nickname: .nickname
        case .bio:      .bio
        case .picture:  .picture
        }
    }
    var coreValue: OctopusCore.ConnectionMode.SSOConfiguration.ProfileField {
        return switch self {
        case .nickname: .nickname
        case .bio:      .bio
        case .picture:  .picture
        }
    }
}

extension ConnectionMode.SSOConfiguration {
    var coreValue: OctopusCore.ConnectionMode.SSOConfiguration {
        return OctopusCore.ConnectionMode.SSOConfiguration(
            appManagedFields: Set(appManagedFields.map(\.coreValue)),
            loginRequired: loginRequired,
            modifyUser: { field in
                modifyUser(.init(from: field))
            })
    }
}

extension ConnectionMode {
    var coreValue: OctopusCore.ConnectionMode {
        return switch self {
        case let .octopus(deepLink):    .octopus(deepLink: deepLink)
        case let .sso(config):          .sso(config.coreValue)
        }
    }
}
