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
    public let displayConfig: DisplayConfig?
    /// Per-field profile editability lock. Absent config ⇒ `.allEditable` ⇒ today's behaviour.
    public let profileFieldsLock: ProfileFieldsLock
    /// Per-content-type creation options (pictures / polls). Absent ⇒ `.allEnabled` ⇒ today's behaviour.
    public let contentOptions: ContentOptions
}

extension CommunityConfig {
    init(from entity: CommunityConfigEntity) {
        self.forceLoginOnStrongActions = entity.forceLoginOnStrongActions
        self.displayAccountAge = entity.displayAccountAge
        self.gamificationConfig = entity.gamificationConfig.map { GamificationConfig(from: $0) }
        self.displayConfig = entity.displayConfig.map { DisplayConfig(from: $0) }
        self.profileFieldsLock = ProfileFieldsLock(from: entity)
        self.contentOptions = ContentOptions(from: entity)
    }

    init(from config: Com_Octopuscommunity_ApiKeyConfig) {
        forceLoginOnStrongActions = config.clientLoginMandatory
        displayAccountAge = config.displayAccountAge
        if config.hasGamificationConfig {
            gamificationConfig = GamificationConfig(from: config.gamificationConfig)
        } else {
            gamificationConfig = nil
        }
        displayConfig = DisplayConfig(from: config.displayConfig)
        if config.hasProfileFieldsLock {
            profileFieldsLock = ProfileFieldsLock(from: config.profileFieldsLock)
        } else {
            profileFieldsLock = .allEditable
        }
        if config.hasContentOptions {
            contentOptions = ContentOptions(from: config.contentOptions)
        } else {
            contentOptions = .allEnabled
        }
    }
}

extension CommunityConfig {
    /// Returns a copy with only `profileFieldsLock` replaced. Internal test affordance used (via an
    /// `@_spi` SDK entry point) by the sample app to exercise the per-field lock without a
    /// backend-driven config (OCT-1487).
    func withProfileFieldsLock(_ lock: ProfileFieldsLock) -> CommunityConfig {
        CommunityConfig(forceLoginOnStrongActions: forceLoginOnStrongActions,
                        displayAccountAge: displayAccountAge,
                        gamificationConfig: gamificationConfig,
                        displayConfig: displayConfig,
                        profileFieldsLock: lock,
                        contentOptions: contentOptions)
    }

    /// Returns a copy with only `contentOptions` replaced. Internal test affordance used (via an
    /// `@_spi` SDK entry point) by the sample app to exercise the content options without a
    /// backend-driven config (OCT-1426).
    func withContentOptions(_ options: ContentOptions) -> CommunityConfig {
        CommunityConfig(forceLoginOnStrongActions: forceLoginOnStrongActions,
                        displayAccountAge: displayAccountAge,
                        gamificationConfig: gamificationConfig,
                        displayConfig: displayConfig,
                        profileFieldsLock: profileFieldsLock,
                        contentOptions: options)
    }
}
