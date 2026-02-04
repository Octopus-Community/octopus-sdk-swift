//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

extension OctopusEvent {
    /// Context of the event .reactionModified
    public protocol ReactionModifiedContext: Sendable {
        /// The previous reaction
        var previousReaction: ReactionKind? { get }
        /// The new reaction. If nil, it means that the reaction has been deleted.
        var newReaction: ReactionKind? { get }
        /// The id of the content that has been deleted
        var contentId: String { get }
        /// The kind of content
        var contentKind: ContentKind { get }
    }
}

extension SdkEvent.ReactionModifiedContext: OctopusEvent.ReactionModifiedContext {
    public var previousReaction: OctopusEvent.ReactionKind? { .init(from: corePreviousReaction) }
    public var newReaction: OctopusEvent.ReactionKind? { .init(from: coreNewReaction) }
    public var contentKind: OctopusEvent.ContentKind { .init(from: coreContentKind) }
}
