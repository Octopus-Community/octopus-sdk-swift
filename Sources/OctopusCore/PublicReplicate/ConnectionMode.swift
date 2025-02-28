//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

/// The kind of connection
public enum ConnectionMode {
    /// Connection and user management is handled by OctopusSDK
    case octopus(deepLink: String?)
    /// You provide to OctopusSDK the user and their lifecycle are tight to their lifecycle in your app
    case sso(SSOConfiguration)
    
    /// Configuration of the SSO connection mode
    public struct SSOConfiguration {
        /// The field of a Profile
        public enum ProfileField {
            /// Username
            case nickname
            /// Biography
            case bio
            /// Profile picture
            case picture
        }

        /// Set of fields that are "associated" with your app. An associated field cannot be updated by Octopus and is
        /// only updated by your app.
        public let appManagedFields: Set<ProfileField>

        /// Block called when OctopusSDK needs a logged in user.
        /// When this block is called, you should start your login process.
        public let loginRequired: () -> Void
        /// Block called when the user tries to modify some fields related to its profile.
        /// When this block is called, you should open the profile edition.
        public let modifyUser: (ProfileField?) -> Void

        /// Constructor.
        /// - Parameters:
        ///   - appManagedFields: Set of fields that are "associated" with your app. An associated field cannot be
        ///                       updated by Octopus and is only updated by your app. If app managed fields is not empty
        ///                       you **must** pass a `modifyUser` block that opens your profile edition UI.
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
