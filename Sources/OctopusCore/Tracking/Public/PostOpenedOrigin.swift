//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

public enum PostOpenedOrigin {
    case clientApp
    case sdk(hasFeaturedComment: Bool)
}

extension PostOpenedOrigin {
    var internalValue: Event.PostOpenedOrigin {
        switch self {
        case .clientApp: .clientApp
        case let .sdk(hasFeaturedComment): .sdk(hasFeaturedComment: hasFeaturedComment)
        }
    }
}
