//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

/// A topic.
///
/// A post is related to exactly one topic.
public struct Topic: Equatable, Sendable {
    /// Id of the topic
    public let id: String
    /// Name of the topic
    public let name: String
}

extension Topic {
    init(from topic: OctopusCore.Topic) {
        self.id = topic.uuid
        self.name = topic.name
    }
}
