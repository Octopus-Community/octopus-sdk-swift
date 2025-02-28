//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(OctoObjectEntity)
class OctoObjectEntity: NSManagedObject, Identifiable {
    @NSManaged public var authorId: String?
    @NSManaged public var authorNickname: String?
    @NSManaged public var authorAvatarUrl: URL?
    @NSManaged public var creationTimestamp: Double
    @NSManaged public var updateTimestamp: Double
    @NSManaged public var statusValue: Int16
    @NSManaged public var statusReasonCodes: String
    @NSManaged public var statusReasonMessages: String
    @NSManaged public var parentId: String
    @NSManaged public var uuid: String

    @NSManaged public var likeCount: Int
    @NSManaged public var childCount: Int
    @NSManaged public var viewCount: Int
    @NSManaged public var userLikeId: String?

    @NSManaged public var descChildrenFeedId: String?
    @NSManaged public var ascChildrenFeedId: String?
}
