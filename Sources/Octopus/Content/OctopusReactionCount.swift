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
    public var reaction: OctopusReactionKind {
        switch self.reactionKind {
        case .heart: .heart
        case .joy: .joy
        case .mouthOpen: .mouthOpen
        case .clap: .clap
        case .cry: .cry
        case .rage: .rage
        case let .unknown(string): .unknown(string)
        }
    }
}
