//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

/// Kind of response
enum ResponseKind {
    case comment
    case reply
}

extension ResponseKind {
    var canReply: Bool {
        switch self {
        case .comment: true
        case .reply: false
        }
    }
}
