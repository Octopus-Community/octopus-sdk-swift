//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(UserConfigEntity)
class UserConfigEntity: NSManagedObject, Identifiable {
    @NSManaged public var canAccessCommunityOptional: NSNumber?
    @NSManaged public var accessDeniedMessage: String?
    /// Why the access is denied, as a `CommunityNoAccessReason.storedName`. `nil` when the access is granted, and on a row
    /// written before the reason was stored.
    @NSManaged public var noAccessReason: String?
    @NSManaged public var banNickname: String?
    @NSManaged public var banPolicyName: String?
    @NSManaged public var banPolicyDescription: String?
    @NSManaged public var banContactEmail: String?

    var canAccessCommunity: Bool? { canAccessCommunityOptional?.boolValue }

    func fill(with config: UserConfig) {
        canAccessCommunityOptional = NSNumber(booleanLiteral: config.canAccessCommunity)
        accessDeniedMessage = config.accessDeniedMessage
        noAccessReason = config.noAccessReason?.storedName
        // The ban details only mean something next to a ban: no other reason may keep the ones of a former ban.
        var ban: CommunityNoAccessReason.BanDetails?
        if case let .accountBanned(details) = config.noAccessReason {
            ban = details
        }
        banNickname = ban?.nickname
        banPolicyName = ban?.policyName
        banPolicyDescription = ban?.policyDescription
        banContactEmail = ban?.contactEmail
    }

    /// The reason the row holds, `nil` when it holds none or one this version does not know.
    var storedNoAccessReason: CommunityNoAccessReason? {
        guard let noAccessReason else { return nil }
        return CommunityNoAccessReason(
            storedName: noAccessReason,
            banDetails: .init(nickname: banNickname, policyName: banPolicyName ?? "",
                              policyDescription: banPolicyDescription ?? "", contactEmail: banContactEmail))
    }
}

// Extension that adds all fetch requests needed
extension UserConfigEntity {
    @nonobjc public class func fetch() -> NSFetchRequest<UserConfigEntity> {
        let request = NSFetchRequest<UserConfigEntity>(entityName: "UserConfig")
        request.fetchLimit = 1
        return request
    }
}
