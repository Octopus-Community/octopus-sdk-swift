//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

extension OctopusEvent {
    /// Context of the event .gamificationPointsGained
    public protocol GamificationPointsGainedContext: Sendable {
        /// The points that have been added
        var pointsGained: Int { get }
        /// The action that led to gaining points
        var action: GamificationPointsGainedAction { get }
    }

    /// An action that led to gaining points
    public enum GamificationPointsGainedAction: Sendable {
        /// The user created a post
        case post
        /// The user created a comment
        case comment
        /// The user created a reply
        case reply
        /// The user sent a reaction
        case reaction
        /// The user voted on a poll
        case vote
        /// The user had one of their post commented by someone else
        case postCommented
        /// The user completed their profile
        case profileCompleted
        /// The user came back in the community for the first time today
        case dailySession
    }
}

extension SdkEvent.GamificationPointsGainedContext: OctopusEvent.GamificationPointsGainedContext {
    public var action: OctopusEvent.GamificationPointsGainedAction { .init(from: coreAction) }
}

extension OctopusEvent.GamificationPointsGainedAction {
    init(from kind: SdkEvent.GamificationPointsGainedContext.Action) {
        self = switch kind {
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
