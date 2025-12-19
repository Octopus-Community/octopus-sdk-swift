//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

/// The configuration of the current community (identified by the API key).
public struct CommunityConfig: Equatable, Sendable {
    /// Whether any strong actions (post, comment, reply, open profile) should open the login flow
    public let forceLoginOnStrongActions: Bool
    public let displayAccountAge: Bool
    public let gamificationConfig: GamificationConfig?
}

extension CommunityConfig {
    init(from entity: CommunityConfigEntity) {
        self.forceLoginOnStrongActions = entity.forceLoginOnStrongActions
        self.displayAccountAge = entity.displayAccountAge
        self.gamificationConfig = entity.gamificationConfig.map { GamificationConfig(from: $0) }
    }

    init(from config: Com_Octopuscommunity_ApiKeyConfig) {
        forceLoginOnStrongActions = config.clientLoginMandatory
        displayAccountAge = config.displayAccountAge
        if config.hasGamificationConfig {
            gamificationConfig = GamificationConfig(from: config.gamificationConfig)
        } else {
            gamificationConfig = nil
        }
    }
}
