//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

/// A protocol giving an information about the total count of reactions done on a content.
public protocol OctopusReactionCount: Equatable, Sendable {
    /// The kind of reaction
    var reaction: OctopusReactionKind { get }
    /// The count
    var count: Int { get }
}

/// Internal conformance of ReactionCount to OctopusReactionCount
extension ReactionCount: OctopusReactionCount {
    public var reaction: OctopusReactionKind { OctopusReactionKind(from: self.reactionKind) }
}
