//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

/// The configuration of the current community (identified by the API key).
public struct CommunityConfig: Sendable {
    /// Whether any strong actions (post, comment, reply, open profile) should open the login flow
    public let forceLoginOnStrongActions: Bool
}

extension CommunityConfig {
    init?(from entity: CommunityConfigEntity) {
        guard let forceLoginOnStrongActions = entity.forceLoginOnStrongActions else { return nil }
        self.forceLoginOnStrongActions = forceLoginOnStrongActions
    }

    init(from config: Com_Octopuscommunity_ApiKeyConfig) {
        forceLoginOnStrongActions = config.clientLoginMandatory
    }
}
