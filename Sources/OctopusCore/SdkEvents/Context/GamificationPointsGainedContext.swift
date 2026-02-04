//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation

extension SdkEvent {
    public struct GamificationPointsGainedContext: Sendable {
        /// The points that have been added
        public let pointsGained: Int
        /// The action that led to gaining points
        public let coreAction: Action

        /// An action that led to gaining points
        public enum Action: Sendable {
            case post
            case comment
            case reply
            case reaction
            case vote
            case postCommented
            case profileCompleted
            case dailySession
        }
    }
}

extension GamificationAction {
    var sdkEventValue: SdkEvent.GamificationPointsGainedContext.Action {
        switch self {
        case .post: .post
        case .comment: .comment
        case .reply: .reply
        case .reaction: .reaction
        case .vote: .vote
        case .postCommented: .postCommented
        case .profileCompleted: .profileCompleted
        case .dailySession: .dailySession
        }
    }
}
