//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

/// The configuration of the current community (identified by the API key).
public struct UserConfig: Equatable {
    /// Whether the user can access the community
    public let canAccessCommunity: Bool
    public let accessDeniedMessage: String?
}

extension UserConfig {
    init?(from entity: UserConfigEntity) {
        guard let canAccessCommunity = entity.canAccessCommunity else { return nil }
        self.canAccessCommunity = canAccessCommunity
        self.accessDeniedMessage = entity.accessDeniedMessage
    }
}
