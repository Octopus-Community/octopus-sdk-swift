//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(MediaEntity)
class MediaEntity: NSManagedObject, Identifiable {
    enum Kind: Int16 {
        case image
        case video
    }
    @NSManaged public var url: URL
    @NSManaged public var thumbnailUrl: URL?
    @NSManaged public var width: Double
    @NSManaged public var height: Double
    @NSManaged public var type: Int16
    @NSManaged public var videoId: String?

    var kind: Kind? { Kind(rawValue: type) }

    var size: CGSize {
        // max with 1 to avoid dividing by 0
        CGSize(width: max(width, 1), height: max(height, 1))
    }

    func fill(with media: Media, context: NSManagedObjectContext) {
        url = media.url
        thumbnailUrl = media.thumbnailUrl
        type = media.kind.entity.rawValue
        width = media.size.width
        height = media.size.height
        videoId = media.videoId
    }
}
