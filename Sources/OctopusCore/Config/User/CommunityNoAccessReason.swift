//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

/// Why the access to the community is denied.
public enum CommunityNoAccessReason: Equatable, Sendable {
    /// What the server says about the ban of an account.
    public struct BanDetails: Equatable, Sendable {
        /// The nickname of the banned account, `nil` when the server does not give one.
        public let nickname: String?
        /// The name of the policy the account broke.
        public let policyName: String
        /// The text of that policy, as the community wrote it.
        public let policyDescription: String
        /// The address to write to in order to appeal, `nil` when the server does not give one.
        public let contactEmail: String?

        public init(nickname: String?, policyName: String, policyDescription: String, contactEmail: String?) {
            self.nickname = nickname?.nilIfBlank
            self.policyName = policyName
            self.policyDescription = policyDescription
            self.contactEmail = contactEmail?.nilIfBlank
        }

        /// What the host app is told about the ban when the server gives no message of its own. In English only:
        /// it is the fallback of an error message, not a text of the SDK's screens.
        var fallbackBanMessage: String {
            if let nickname {
                return "Your account @\(nickname) was banned for breaking the “\(policyName)” policy."
            }
            return "Your account was banned for breaking the “\(policyName)” policy."
        }
    }

    /// The user is not in the part of the audience the community is opened to.
    case cohort
    /// The community is disabled for a while.
    case temporarilyDisabled
    /// The community is closed.
    case closed
    /// The member is excluded from the community.
    case memberExcluded
    /// The account is banned. The details are `nil` as long as they are not read: right after launch, the kind of
    /// the reason is known before what the database holds about it.
    case accountBanned(BanDetails?)
    /// The account has been deleted.
    case accountDeleted
    /// The server gives no reason, or one this version does not know.
    case unknown
}

extension CommunityNoAccessReason {
    /// The reason the response gives, `nil` when it grants the access.
    init?(from response: Com_Octopuscommunity_CanAccessCommunityResponse) {
        guard !response.canAccessCommunity else { return nil }
        switch response.noAccessReason {
        case .noAccessCohort?:
            self = .cohort
        case .memberExcluded?:
            self = .memberExcluded
        case let .accountBanned(ban)?:
            self = .accountBanned(BanDetails(
                nickname: ban.hasNickname ? ban.nickname : nil,
                policyName: ban.policyName,
                policyDescription: ban.policyDescription,
                contactEmail: ban.hasContactEmail ? ban.contactEmail : nil))
        case .accountDeleted?:
            self = .accountDeleted
        // An ended session is replaced, never stored as an access: `UserConfigDatabase.store(accessRead:session:)`
        // stops before this.
        case .sessionEnded?, nil:
            self = .unknown
        }
    }

    /// The name the kind of the reason is stored under. These names are stored: never rename one.
    var storedName: String {
        switch self {
        case .cohort: "cohort"
        case .temporarilyDisabled: "temporarilyDisabled"
        case .closed: "closed"
        case .memberExcluded: "memberExcluded"
        case .accountBanned: "accountBanned"
        case .accountDeleted: "accountDeleted"
        case .unknown: "unknown"
        }
    }

    /// The reason stored under `storedName`, `nil` when this version does not know that name.
    /// - Parameter banDetails: the details that go with a ban, `nil` when they are not read yet.
    init?(storedName: String, banDetails: BanDetails?) {
        switch storedName {
        case "cohort": self = .cohort
        case "temporarilyDisabled": self = .temporarilyDisabled
        case "closed": self = .closed
        case "memberExcluded": self = .memberExcluded
        case "accountBanned": self = .accountBanned(banDetails)
        case "accountDeleted": self = .accountDeleted
        case "unknown": self = .unknown
        default: return nil
        }
    }

    /// The reason a closure of the community stands for.
    init(closureKind: CommunityClosure.Kind) {
        switch closureKind {
        case .closed: self = .closed
        case .temporarilyDisabled: self = .temporarilyDisabled
        }
    }
}
