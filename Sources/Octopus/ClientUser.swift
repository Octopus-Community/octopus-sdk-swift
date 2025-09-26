//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import UIKit
import OctopusCore

/// A user owned by the client (i.e. you).
/// If the `ConnectionMode` of the SDK is `.sso`, you will need to pass your user so OctopusCommunity could "transform"
/// it into an Octopus Community user. This is done using `OctopusSDK.setClientUser(:)` function.
public struct ClientUser: Sendable {
    /// Age information about your user
    public enum AgeInformation: Sendable {
        /// Your user has reached the minimum legal age (16 years old by default).
        case legalAgeReached
        /// Your user has not reached the minimum legal age.
        case underaged
    }

    /// Profile of your user
    public struct Profile: Sendable {
        /// Its nickname.
        let nickname: String?
        /// Its bio
        let bio: String?
        /// Its picture. This Data will be transformed into an UIImage using `UIImage(data:)` so it must be compatible.
        let picture: Data?
        /// The age information. Nil if unknown.
        @available(*, deprecated, message: "Age information is not used anymore. It will always be nil")
        var ageInformation: AgeInformation? { nil }

        /// Constructor.
        ///
        /// - Parameters:
        ///   - nickname: Nickname of your user. Default value is nil.
        ///   - bio: Description of your user. Default value is nil.
        ///   - picture: Picture data of your user. Default value is nil.
        ///              This Data will be transformed into an UIImage using `UIImage(data:)` so it must be compatible.
        ///   - ageInformation: Age information of your user. Nil if unknown. Default value is nil.
        @available(*, deprecated, message: "Use instead init(nickname: String?, bio: String?, picture: Data?). Age information is not used anymore.")
        public init(nickname: String? = nil,
                    bio: String? = nil,
                    picture: Data? = nil,
                    ageInformation: AgeInformation? = nil) {
            self.nickname = nickname
            self.bio = bio
            self.picture = picture
        }

        /// Constructor.
        ///
        /// - Parameters:
        ///   - nickname: Nickname of your user. Default value is nil.
        ///   - bio: Description of your user. Default value is nil.
        ///   - picture: Picture data of your user. Default value is nil.
        ///              This Data will be transformed into an UIImage using `UIImage(data:)` so it must be compatible.
        public init(nickname: String? = nil,
                    bio: String? = nil,
                    picture: Data? = nil) {
            self.nickname = nickname
            self.bio = bio
            self.picture = picture
        }
    }

    /// A unique identifier for this user.
    let userId: String
    /// The profile of your user.
    let profile: Profile

    /// Constructor.
    ///
    /// - Parameters:
    ///   - userId: A unique identifier for this user.
    ///   - profile: The profile of your user.
    public init(userId: String, profile: Profile) {
        self.userId = userId
        self.profile = profile
    }
}

extension ClientUser.Profile {
    var coreValue: OctopusCore.ClientUserProfile {
        .init(nickname: nickname, bio: bio, picture: picture)
    }
}

extension ClientUser {
    var coreValue: OctopusCore.ClientUser {
        .init(userId: userId, profile: profile.coreValue)
    }
}
