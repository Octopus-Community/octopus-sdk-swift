//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Octopus

/// Struct representing your user.
/// If you don't handle one field, it will be passed as nil to the SDK
struct AppUser: Equatable {
    /// A unique, stable, identifier for this user
    let userId: String
    /// A nickname
    var nickname: String?
    /// The biography for this user
    var bio: String?
    /// A profile picture
    var picture: Data?
}
