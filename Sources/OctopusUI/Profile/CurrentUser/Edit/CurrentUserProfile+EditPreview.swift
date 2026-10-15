//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import OctopusCore

extension CurrentUserProfile {
    /// The community avatar the profile edit preview draws when the member has no picture (or removes it).
    /// The two are never both set: while the member has a picture, it is the default they would get once they tap
    /// "remove".
    var editPreviewDefaultAvatar: DefaultAvatar? { defaultAvatar ?? defaultAvatarIfPictureRemoved }
}
