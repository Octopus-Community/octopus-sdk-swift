//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

/// The configuration of the current community (identified by the API key).
public struct UserConfig: Equatable, Sendable {
    /// Whether the user can access the community
    public let canAccessCommunity: Bool
    public let accessDeniedMessage: String?
    /// Why the access is denied. Not `nil` if and only if `canAccessCommunity` is `false`.
    public let noAccessReason: CommunityNoAccessReason?

    init(canAccessCommunity: Bool, accessDeniedMessage: String?, noAccessReason: CommunityNoAccessReason? = nil) {
        self.canAccessCommunity = canAccessCommunity
        self.accessDeniedMessage = accessDeniedMessage
        self.noAccessReason = canAccessCommunity ? nil : (noAccessReason ?? .unknown)
    }
}

extension UserConfig {
    /// The message of the ban when the access is denied because the account is banned, `nil` otherwise: the one of
    /// the server, or a sentence naming the policy when it gives none. `nil` too as long as the details of the ban
    /// are not read, since nothing can be said about it yet.
    var banMessage: String? {
        guard case let .accountBanned(details?) = noAccessReason else { return nil }
        return accessDeniedMessage ?? details.fallbackBanMessage
    }

    init(from response: Com_Octopuscommunity_CanAccessCommunityResponse) {
        self.init(canAccessCommunity: response.canAccessCommunity,
                  accessDeniedMessage: response.communityDisabledMessage.nilIfEmpty,
                  noAccessReason: CommunityNoAccessReason(from: response))
    }

    init?(from entity: UserConfigEntity) {
        guard let canAccessCommunity = entity.canAccessCommunity else { return nil }
        // A refused row without a reason (or with one this version does not know) reads as unknown
        self.init(canAccessCommunity: canAccessCommunity, accessDeniedMessage: entity.accessDeniedMessage,
                  noAccessReason: entity.storedNoAccessReason)
    }
}
