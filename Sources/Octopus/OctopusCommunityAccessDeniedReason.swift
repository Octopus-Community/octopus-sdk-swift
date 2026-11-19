//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

/// Why the current user cannot access the community.
///
/// Read it on ``OctopusSDK/communityAccessDeniedReason``, next to ``OctopusSDK/hasAccessToCommunity``.
#if hasAttribute(nonexhaustive)
@nonexhaustive
#endif
public enum OctopusCommunityAccessDeniedReason: Sendable {
    /// The user is not part of the audience the community is opened to (for example, they are out of the A/B test
    /// cohort).
    case notInCohort
    /// The community is disabled for a while. It is expected to come back.
    case communityTemporarilyDisabled
    /// The community is closed.
    case communityClosed
    /// The member is excluded from the community.
    case memberExcluded
    /// The account of the member is banned. The details of the ban (the policy that was broken, who to contact) are
    /// displayed by the SDK and are not exposed.
    case accountBanned
    /// The account of the member has been deleted. Your app can disconnect the member on its side, with
    /// ``OctopusSDK/disconnectUser()``. The SDK lets the member access the community again from its screen.
    case accountDeleted
    /// The server gives no reason, or gives one that this version of the SDK does not know.
    case unknown
}

extension OctopusCommunityAccessDeniedReason {
    init(from reason: CommunityNoAccessReason) {
        self = switch reason {
        case .cohort: .notInCohort
        case .temporarilyDisabled: .communityTemporarilyDisabled
        case .closed: .communityClosed
        case .memberExcluded: .memberExcluded
        case .accountBanned: .accountBanned
        case .accountDeleted: .accountDeleted
        case .unknown: .unknown
        }
    }

    /// The reason the access state gives, `nil` when no access state is known or when the access is granted.
    init?(userConfig: UserConfig?) {
        guard let reason = userConfig?.noAccessReason else { return nil }
        self.init(from: reason)
    }
}
