//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

public protocol OctopusContent: Equatable, Sendable {
    var uuid: String { get }
    var author: MinimalProfile? { get }
    var creationDate: Date { get }
    var updateDate: Date { get }
    var parentId: String { get }
    var aggregatedInfo: AggregatedInfo { get }
    var userInteractions: UserInteractions { get }
    var status: Status { get }
}

extension Post: OctopusContent { }
extension Comment: OctopusContent { }
extension Reply: OctopusContent { }
