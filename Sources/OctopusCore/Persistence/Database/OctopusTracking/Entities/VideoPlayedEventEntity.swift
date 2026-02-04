//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(VideoPlayedEventEntity)
class VideoPlayedEventEntity: EventEntity {
    @NSManaged public var octoObjectId: String
    @NSManaged public var videoId: String
    @NSManaged public var watchTime: TimeInterval
    @NSManaged public var duration: TimeInterval
}
