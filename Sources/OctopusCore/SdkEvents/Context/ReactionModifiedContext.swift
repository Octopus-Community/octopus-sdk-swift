//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

extension SdkEvent {
    public struct ReactionModifiedContext: Sendable {
        /// The previous reaction
        public let corePreviousReaction: ReactionKind?
        /// The new reaction. If nil, it means that the reaction has been deleted.
        public let coreNewReaction: ReactionKind?
        /// The id of the content that has been deleted
        public let contentId: String
        /// The kind of content
        public let coreContentKind: ContentKind
    }
}
