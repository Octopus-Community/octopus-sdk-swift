//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusGrpcModels
@testable import OctopusCore

/// `GamificationConfig(from:)` and `GamificationLevel(from:startAt:)`: the community's points and levels, as received
/// from the server.
struct GamificationConfigMappingTests {

    @Test func mapsTheNames() {
        let config = GamificationConfig(from: Com_Octopuscommunity_GamificationConfig.with {
            $0.pointsName = "Stars"
            $0.shortenPointSingular = "st"
            $0.shortenPointPlural = "sts"
        })

        #expect(config.pointsName == "Stars")
        #expect(config.abbrevPointSingular == "st")
        #expect(config.abbrevPointPlural == "sts")
    }

    @Test func mapsEachActionToItsPoints() {
        let config = GamificationConfig(from: Com_Octopuscommunity_GamificationConfig.with {
            $0.reactPts = 1
            $0.votePts = 2
            $0.postPts = 3
            $0.commentPts = 4
            $0.replyPts = 5
            $0.commentOnYourPostPts = 6
            $0.loginPts = 7
            $0.completeProfilePts = 8
        })

        #expect(config.pointsByAction == [
            .reaction: 1,
            .vote: 2,
            .post: 3,
            .comment: 4,
            .reply: 5,
            .postCommented: 6,
            .dailySession: 7,
            .profileCompleted: 8
        ])
    }

    @Test func leavesOutTheActionsWithoutPoints() {
        let config = GamificationConfig(from: Com_Octopuscommunity_GamificationConfig.with {
            $0.postPts = 10
            $0.loginPts = 2
        })

        #expect(config.pointsByAction == [.post: 10, .dailySession: 2])
    }

    @Test func eachLevelStartsWhereThePreviousOneEnds() {
        let config = GamificationConfig(from: Com_Octopuscommunity_GamificationConfig.with {
            $0.gamificationLevels = [
                .with { $0.level = 1; $0.name = "Newcomer"; $0.nextLevelAt = 100 },
                .with { $0.level = 2; $0.name = "Regular"; $0.nextLevelAt = 250 },
                .with { $0.level = 3; $0.name = "Expert" }
            ]
        })

        #expect(config.gamificationLevels.map(\.level) == [1, 2, 3])
        #expect(config.gamificationLevels.map(\.name) == ["Newcomer", "Regular", "Expert"])
        #expect(config.gamificationLevels.map(\.startAt) == [0, 100, 250])
        // The last level has no next one.
        #expect(config.gamificationLevels.map(\.nextLevelAt) == [100, 250, nil])
    }

    @Test func aBadgeColorNeedsBothItsLightAndDarkValues() {
        let complete = GamificationLevel(from: Com_Octopuscommunity_GamificationLevel.with {
            $0.badgeLightColorHex = "#FFFFFF"
            $0.badgeDarkColorHex = "#000000"
            $0.badgeTextLightColorHex = "#111111"
            $0.badgeTextDarkColorHex = "#EEEEEE"
        }, startAt: nil)
        let lightOnly = GamificationLevel(from: Com_Octopuscommunity_GamificationLevel.with {
            $0.badgeLightColorHex = "#FFFFFF"
            $0.badgeTextLightColorHex = "#111111"
        }, startAt: nil)
        let darkOnly = GamificationLevel(from: Com_Octopuscommunity_GamificationLevel.with {
            $0.badgeDarkColorHex = "#000000"
            $0.badgeTextDarkColorHex = "#EEEEEE"
        }, startAt: nil)

        #expect(complete.badgeColor == DynamicColor(lightValue: "#FFFFFF", darkValue: "#000000"))
        #expect(complete.badgeTextColor == DynamicColor(lightValue: "#111111", darkValue: "#EEEEEE"))
        #expect(lightOnly.badgeColor == nil)
        #expect(lightOnly.badgeTextColor == nil)
        #expect(darkOnly.badgeColor == nil)
        #expect(darkOnly.badgeTextColor == nil)
    }
}
