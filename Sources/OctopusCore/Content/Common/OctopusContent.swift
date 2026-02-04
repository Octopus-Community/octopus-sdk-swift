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
    var contentKind: ContentKind { get }
}

public enum ContentKind {
    case post
    case comment
    case reply
}

extension Post: OctopusContent {
    public var contentKind: ContentKind { .post }
}
extension Comment: OctopusContent {
    public var contentKind: ContentKind { .comment }
}
extension Reply: OctopusContent {
    public var contentKind: ContentKind { .reply }
}
