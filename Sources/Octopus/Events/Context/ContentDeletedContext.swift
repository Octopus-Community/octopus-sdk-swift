//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

extension OctopusEvent {
    /// Context of the event .contentDeleted
    public protocol ContentDeletedContext: Sendable {
        /// The id of the content that has been deleted
        var contentId: String { get }
        /// The kind of content
        var kind: ContentKind { get }
    }
}

extension SdkEvent.ContentDeletedContext: OctopusEvent.ContentDeletedContext {
    public var kind: OctopusEvent.ContentKind { .init(from: coreKind) }
}
