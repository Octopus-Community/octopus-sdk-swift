//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels
import SwiftProtobuf

public struct AggregatedInfo: Equatable, Sendable {
    public let likeCount: Int
    public let childCount: Int
    public let viewCount: Int
}

extension AggregatedInfo {
    public static let empty: AggregatedInfo = .init(likeCount: 0, childCount: 0, viewCount: 0)

    init(from aggregate: Com_Octopuscommunity_Aggregate) {
        likeCount = Int(aggregate.likeCount)
        childCount = Int(aggregate.childrenCount)
        viewCount = Int(aggregate.viewCount)
    }

    init(from entity: OctoObjectEntity) {
        likeCount = entity.likeCount
        childCount = entity.childCount
        viewCount = entity.viewCount
    }
}
