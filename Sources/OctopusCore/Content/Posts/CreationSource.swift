//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

public extension PostsRepository {
    enum CreationSource: Sendable, Equatable {
        case user
        case prefilledFromClient

        var proto: Com_Octopuscommunity_PutRequest.CreationSource {
            switch self {
            case .user: return .user
            case .prefilledFromClient: return .prefilledFromClient
            }
        }
    }
}
