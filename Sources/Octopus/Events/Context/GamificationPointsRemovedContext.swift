//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

extension OctopusEvent {
    /// Context of the event .gamificationPointsRemoved
    public protocol GamificationPointsRemovedContext: Sendable {
        /// The points that have been removed
        var pointsRemoved: Int { get }
        /// The action that led to losing points
        var action: GamificationPointsRemovedAction { get }
    }

    /// An action that led to losing points
    public enum GamificationPointsRemovedAction: Sendable {
        case postDeleted
        case commentDeleted
        case replyDeleted
        case reactionDeleted
    }
}

extension SdkEvent.GamificationPointsRemovedContext: OctopusEvent.GamificationPointsRemovedContext {
    public var action: OctopusEvent.GamificationPointsRemovedAction { .init(from: coreAction) }
}

extension OctopusEvent.GamificationPointsRemovedAction {
    init(from kind: SdkEvent.GamificationPointsRemovedContext.Action) {
        self = switch kind {
        case .postDeleted: .postDeleted
        case .commentDeleted: .commentDeleted
        case .replyDeleted: .replyDeleted
        case .reactionDeleted: .reactionDeleted
        }
    }
}
