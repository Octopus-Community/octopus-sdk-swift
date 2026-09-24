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
    /// Activation flag of the Unified Profile feature. When `true`, the community exposes members'
    /// client user ids (`MinimalProfile.clientUserId` / `Profile.clientUserId`) so a tap on a member's
    /// profile can hand the host that member's client user id and let it open its own profile screen.
    /// The feature is only active when this flag AND the host-wired `onNavigateToProfile` callback are
    /// both set; otherwise profile taps keep opening the SDK's native profile screens. Absent /
    /// unseeded ⇒ `false` ⇒ today's native-profile behaviour.
    public let exposeClientUserId: Bool
    /// How users must accept the legal documents at their first contribution. Absent ⇒ `.implicit`
    /// ⇒ today's behaviour (implicit acceptance, no consent sheet).
    public let termsAcceptanceMode: TermsAcceptanceMode
    /// Whether the profile "Comments" tab is shown on *other* users' profiles. The tab is
    /// always shown on the connected user's own profile; this flag only gates it on other members'
    /// profiles. Set internally per-community in the back-office at the client's request. Absent /
    /// unseeded ⇒ `false` ⇒ the Comments tab stays private (own profile only).
    public let showCommentsOnOtherProfiles: Bool
}

extension CommunityConfig {
    init(from entity: CommunityConfigEntity) {
        self.forceLoginOnStrongActions = entity.forceLoginOnStrongActions
        self.displayAccountAge = entity.displayAccountAge
        self.gamificationConfig = entity.gamificationConfig.map { GamificationConfig(from: $0) }
        self.displayConfig = entity.displayConfig.map { DisplayConfig(from: $0) }
        self.profileFieldsLock = ProfileFieldsLock(from: entity)
        self.contentOptions = ContentOptions(from: entity)
        self.exposeClientUserId = entity.exposeClientUserId
        self.termsAcceptanceMode = TermsAcceptanceMode(storageValue: entity.termsAcceptanceMode)
        self.showCommentsOnOtherProfiles = entity.showCommentsOnOtherProfiles
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
        // ApiKeyConfig.exposeClientUserId is a plain proto3 bool (false when unset).
        exposeClientUserId = config.exposeClientUserID
        // ApiKeyConfig.termsAcceptanceMode is a plain proto3 enum (.implicit when unset).
        termsAcceptanceMode = TermsAcceptanceMode(from: config.termsAcceptanceMode)
        // ApiKeyConfig.showCommentsOnOtherProfiles is a plain proto3 bool (false when unset).
        showCommentsOnOtherProfiles = config.showCommentsOnOtherProfiles
    }
}

extension CommunityConfig {
    /// Returns a copy with only `profileFieldsLock` replaced. Internal test affordance used (via an
    /// `@_spi` SDK entry point) by the sample app to exercise the per-field lock without a
    /// backend-driven config.
    func withProfileFieldsLock(_ lock: ProfileFieldsLock) -> CommunityConfig {
        CommunityConfig(forceLoginOnStrongActions: forceLoginOnStrongActions,
                        displayAccountAge: displayAccountAge,
                        gamificationConfig: gamificationConfig,
                        displayConfig: displayConfig,
                        profileFieldsLock: lock,
                        contentOptions: contentOptions,
                        exposeClientUserId: exposeClientUserId,
                        termsAcceptanceMode: termsAcceptanceMode,
                        showCommentsOnOtherProfiles: showCommentsOnOtherProfiles)
    }

    /// Returns a copy with only `contentOptions` replaced. Internal test affordance used (via an
    /// `@_spi` SDK entry point) by the sample app to exercise the content options without a
    /// backend-driven config.
    func withContentOptions(_ options: ContentOptions) -> CommunityConfig {
        CommunityConfig(forceLoginOnStrongActions: forceLoginOnStrongActions,
                        displayAccountAge: displayAccountAge,
                        gamificationConfig: gamificationConfig,
                        displayConfig: displayConfig,
                        profileFieldsLock: profileFieldsLock,
                        contentOptions: options,
                        exposeClientUserId: exposeClientUserId,
                        termsAcceptanceMode: termsAcceptanceMode,
                        showCommentsOnOtherProfiles: showCommentsOnOtherProfiles)
    }

    /// Returns a copy with only `exposeClientUserId` replaced. Internal test affordance used (via an
    /// `@_spi` SDK entry point) by the sample app to exercise the Unified Profile activation flag
    /// without a backend-driven config.
    func withExposeClientUserId(_ enabled: Bool) -> CommunityConfig {
        CommunityConfig(forceLoginOnStrongActions: forceLoginOnStrongActions,
                        displayAccountAge: displayAccountAge,
                        gamificationConfig: gamificationConfig,
                        displayConfig: displayConfig,
                        profileFieldsLock: profileFieldsLock,
                        contentOptions: contentOptions,
                        exposeClientUserId: enabled,
                        termsAcceptanceMode: termsAcceptanceMode,
                        showCommentsOnOtherProfiles: showCommentsOnOtherProfiles)
    }

    /// Returns a copy with only `termsAcceptanceMode` replaced. Internal test affordance used (via an
    /// `@_spi` SDK entry point) by the sample app to exercise the explicit-consent modes without a
    /// backend-driven config.
    func withTermsAcceptanceMode(_ mode: TermsAcceptanceMode) -> CommunityConfig {
        CommunityConfig(forceLoginOnStrongActions: forceLoginOnStrongActions,
                        displayAccountAge: displayAccountAge,
                        gamificationConfig: gamificationConfig,
                        displayConfig: displayConfig,
                        profileFieldsLock: profileFieldsLock,
                        contentOptions: contentOptions,
                        exposeClientUserId: exposeClientUserId,
                        termsAcceptanceMode: mode,
                        showCommentsOnOtherProfiles: showCommentsOnOtherProfiles)
    }

    /// Returns a copy with only `showCommentsOnOtherProfiles` replaced. Internal test affordance used
    /// (via an `@_spi` SDK entry point) by the sample app to exercise the profile Comments tab on other
    /// users' profiles without a backend-driven config.
    func withShowCommentsOnOtherProfiles(_ enabled: Bool) -> CommunityConfig {
        CommunityConfig(forceLoginOnStrongActions: forceLoginOnStrongActions,
                        displayAccountAge: displayAccountAge,
                        gamificationConfig: gamificationConfig,
                        displayConfig: displayConfig,
                        profileFieldsLock: profileFieldsLock,
                        contentOptions: contentOptions,
                        exposeClientUserId: exposeClientUserId,
                        termsAcceptanceMode: termsAcceptanceMode,
                        showCommentsOnOtherProfiles: enabled)
    }
}
