//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

extension SdkEvent {
    public enum ContentKind: Sendable {
        case post
        case comment
        case reply
    }
}

extension ContentKind {
    var sdkEventValue: SdkEvent.ContentKind {
        switch self {
        case .post: .post
        case .comment: .comment
        case .reply: .reply
        }
    }
}
