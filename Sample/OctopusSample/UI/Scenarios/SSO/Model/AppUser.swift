//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

/// Struct representing your user.
/// If you don't handle one field, it will be passed as nil to the SDK
struct AppUser {
    enum AgeInfo {
        // More than 16 or 16 years old
        case moreThan16
        // Less than 16 years old
        case lessThan16
    }

    /// A unique, stable, identifier for this user
    let userId: String
    /// A nickname
    var nickname: String?
    /// The biography for this user
    var bio: String?
    /// A profile picture
    var picture: Data?
    /// Information about the age
    var ageInformation: AgeInfo?
}
