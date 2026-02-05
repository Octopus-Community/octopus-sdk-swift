//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

extension SdkEvent {
    public struct ContentDeletedContext: Sendable {
        /// The id of the content that has been deleted
        public let contentId: String
        /// The kind of content
        public let coreKind: ContentKind
    }
}
