//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels

public struct GamificationLevel: Equatable, Sendable {
    public let level: Int
    public let name: String
    public let startAt: Int
    public let nextLevelAt: Int?
    public let badgeColor: DynamicColor?
    public let badgeTextColor: DynamicColor?

    /// Public constructor, only for SwiftUI previews
    public init(level: Int, name: String, startAt: Int, nextLevelAt: Int?, badgeColor: DynamicColor?, badgeTextColor: DynamicColor?) {
        self.level = level
        self.name = name
        self.startAt = startAt
        self.nextLevelAt = nextLevelAt
        self.badgeColor = badgeColor
        self.badgeTextColor = badgeTextColor
    }
}

extension GamificationLevel {
    init(from entity: GamificationLevelEntity, startAt: Int?) {
        level = entity.level
        name = entity.name
        self.startAt = startAt ?? 0
        nextLevelAt = entity.nextLevelAt
        if let badgeLightColorHex = entity.badgeLightColorHex, let badgeDarkColorHex = entity.badgeDarkColorHex {
            badgeColor = DynamicColor(hexLight: badgeLightColorHex, hexDark: badgeDarkColorHex)
        } else {
            badgeColor = nil
        }
        if let badgeTextLightColorHex = entity.badgeTextLightColorHex,
           let badgeTextDarkColorHex = entity.badgeTextDarkColorHex {
            badgeTextColor = DynamicColor(hexLight: badgeTextLightColorHex, hexDark: badgeTextDarkColorHex)
        } else {
            badgeTextColor = nil
        }
    }

    init(from gamifLevel: Com_Octopuscommunity_GamificationLevel, startAt: Int32?) {
        level = Int(gamifLevel.level)
        name = gamifLevel.name
        self.startAt = startAt.map { Int($0) } ?? 0
        nextLevelAt = gamifLevel.hasNextLevelAt ? Int(gamifLevel.nextLevelAt) : nil
        if gamifLevel.hasBadgeDarkColorHex, gamifLevel.hasBadgeLightColorHex {
            badgeColor = DynamicColor(hexLight: gamifLevel.badgeLightColorHex, hexDark: gamifLevel.badgeDarkColorHex)
        } else {
            badgeColor = nil
        }
        if gamifLevel.hasBadgeTextDarkColorHex, gamifLevel.hasBadgeTextLightColorHex {
            badgeTextColor = DynamicColor(hexLight: gamifLevel.badgeTextLightColorHex,
                                          hexDark: gamifLevel.badgeTextDarkColorHex)
        } else {
            badgeTextColor = nil
        }
    }
}
