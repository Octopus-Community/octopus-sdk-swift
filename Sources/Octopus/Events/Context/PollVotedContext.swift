//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

extension OctopusEvent {
    /// Context of the event .pollVoted
    public protocol PollVotedContext: Sendable {
        /// The id of the content (i.e. the post)
        var contentId: String { get }
        /// The id of the option voted by the user
        var optionId: String { get }
    }
}

extension SdkEvent.PollVotedContext: OctopusEvent.PollVotedContext { }
