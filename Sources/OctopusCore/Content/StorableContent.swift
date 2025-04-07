//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

protocol StorableContent {
    var uuid: String { get }
    var author: MinimalProfile? { get }
    var creationDate: Date { get }
    var updateDate: Date { get }
    var status: StorableStatus { get }
    var statusReasons: [StorableStatusReason] { get }
    var parentId: String { get }
    var aggregatedInfo: AggregatedInfo { get }
    var userInteractions: UserInteractions { get }
}
