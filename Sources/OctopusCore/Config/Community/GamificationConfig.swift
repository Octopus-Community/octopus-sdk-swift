//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

/// The configuration of the gamification
public struct GamificationConfig: Equatable, Sendable {
    public let pointsName: String
    public let abbrevPointSingular: String
    public let abbrevPointPlural: String

    public let pointsByAction: [GamificationAction: Int]

    public let gamificationLevels: [GamificationLevel]
}

/// Kind of actions that have a impact on the scoring
public enum GamificationAction: Equatable, Sendable {
    case reaction
    case comment
    case post
    case reply
    case vote
    case postCommented
    case profileCompleted
    case dailySession
}

extension GamificationConfig {
    init(from entity: GamificationConfigEntity) {
        pointsName = entity.pointsName
        abbrevPointSingular = entity.abbrevPointSingular
        abbrevPointPlural = entity.abbrevPointPlural

        pointsByAction = [
            .reaction: entity.reactPts > 0 ? entity.reactPts : nil,
            .vote: entity.votePts > 0 ? entity.votePts : nil,
            .post: entity.postPts > 0 ? entity.postPts : nil,
            .comment: entity.commentPts > 0 ? entity.commentPts : nil,
            .reply: entity.replyPts > 0 ? entity.replyPts : nil,
            .postCommented: entity.commentOnYourPostPts > 0 ? entity.commentOnYourPostPts : nil,
            .dailySession: entity.loginPts > 0 ? entity.loginPts : nil,
            .profileCompleted: entity.completeProfilePts > 0 ? entity.completeProfilePts : nil
        ].compactMapValues { $0 }

        gamificationLevels = entity.gamificationLevels
            .withPrevious()
            .map { previousLevel, currentLevel in
                GamificationLevel(from: currentLevel, startAt: previousLevel?.nextLevelAt)
            }
    }

    init(from config: Com_Octopuscommunity_GamificationConfig) {
        pointsName = config.pointsName
        abbrevPointSingular = config.shortenPointSingular
        abbrevPointPlural = config.shortenPointPlural

        pointsByAction = [
            .reaction: config.hasReactPts ? Int(config.reactPts) : nil,
            .vote: config.hasVotePts ? Int(config.votePts) : nil,
            .post: config.hasPostPts ? Int(config.postPts) : nil,
            .comment: config.hasCommentPts ? Int(config.commentPts) : nil,
            .reply: config.hasReplyPts ? Int(config.replyPts) : nil,
            .postCommented: config.hasCommentOnYourPostPts ? Int(config.commentOnYourPostPts) : nil,
            .dailySession: config.hasLoginPts ? Int(config.loginPts) : nil,
            .profileCompleted: config.hasCompleteProfilePts ? Int(config.completeProfilePts) : nil
        ].compactMapValues { $0 }

        gamificationLevels = config.gamificationLevels
            .withPrevious()
            .map { previousLevel, currentLevel in
                GamificationLevel(from: currentLevel, startAt: previousLevel?.nextLevelAt)
            }
    }
}
