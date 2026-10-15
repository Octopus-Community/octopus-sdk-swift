//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

/// An entity that stores a `DefaultAvatar` in three optional string attributes, all `nil` when there is none.
protocol DefaultAvatarStoring: AnyObject {
    var defaultAvatarBackgroundHex: String? { get set }
    var defaultAvatarInitialsHex: String? { get set }
    var defaultAvatarImageUrl: String? { get set }
}

extension DefaultAvatarStoring {
    var defaultAvatar: DefaultAvatar? {
        get {
            DefaultAvatar(backgroundHex: defaultAvatarBackgroundHex, initialsHex: defaultAvatarInitialsHex,
                          imageUrl: defaultAvatarImageUrl)
        }
        set {
            defaultAvatarBackgroundHex = newValue?.backgroundHex
            defaultAvatarInitialsHex = newValue?.initialsHex
            defaultAvatarImageUrl = newValue?.imageUrl?.absoluteString
        }
    }
}
