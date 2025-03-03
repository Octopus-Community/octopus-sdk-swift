//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import UIKit

public struct ClientUser: Sendable, Equatable {
    let userId: String

    let profile: ClientUserProfile

    public init(userId: String, profile: ClientUserProfile) {
        self.userId = userId
        self.profile = profile
    }
}
