//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

@objc(PostOpenedEventEntity)
class PostOpenedEventEntity: EventEntity {
    @NSManaged public var originValue: Int16
    @NSManaged public var originSdkHasFeaturedComment: Bool
    @NSManaged public var success: Bool
}

extension Event.PostOpenedOrigin {
    init?(from entity: PostOpenedEventEntity) {
        switch entity.originValue {
        case 0: self = .clientApp
        case 1: self = .sdk(hasFeaturedComment: entity.originSdkHasFeaturedComment)
        default: return nil
        }
    }

    var originValue: Int16 {
        switch self {
        case .clientApp: return 0
        case .sdk: return 1
        }
    }
}
