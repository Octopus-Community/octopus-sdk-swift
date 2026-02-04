//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

extension SdkEvent {
    public struct PollVotedContext: Sendable {
        /// The id of the content (i.e. the post)
        public let contentId: String
        /// The id of the option voted by the user
        public let optionId: String
    }
}
