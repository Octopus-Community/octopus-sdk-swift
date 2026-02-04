//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import os

extension SdkEvent {
    public struct GamificationPointsRemovedContext: Sendable {
        /// The points that have been removed
        public let pointsRemoved: Int
        /// The action that led to losing points
        public let coreAction: Action

        /// An action that led to gaining points
        public enum Action: Sendable {
            case postDeleted
            case commentDeleted
            case replyDeleted
            case reactionDeleted
        }
    }
}

extension GamificationAction {
    var pointsRemovedSdkEventValue: SdkEvent.GamificationPointsRemovedContext.Action? {
        switch self {
        case .post: return .postDeleted
        case .comment: return .commentDeleted
        case .reply: return .replyDeleted
        case .reaction: return .reactionDeleted
        default:
            if #available(iOS 14, *) {
                Logger.tracking.debug("Dev error: \(String(describing: self)) cannot be converted to GamificationPointsRemovedContext.Action")
            }
            return nil
        }
    }
}
