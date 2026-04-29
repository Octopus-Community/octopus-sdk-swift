//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import OctopusCore

struct GamificationScoreToTargetView: View {
    @Environment(\.octopusTheme) private var theme

    let gamificationLevel: GamificationLevel
    let gamificationScore: Int
    let gamificationConfig: GamificationConfig

    var body: some View {
        HStack(spacing: 0) {
            if let nextLevelAt = gamificationLevel.nextLevelAt {
                Text(verbatim: "\(gamificationScore) / \(nextLevelAt) \(gamificationConfig.pointsName)")
            } else {
                Text(verbatim: "\(gamificationScore) \(gamificationConfig.pointsName)")
            }

            IconImage(theme.assets.icons.gamification.info)
                .scaleEffect(1.1)
                .padding(.horizontal, 2)
        }
        .font(theme.fonts.caption1.weight(.semibold))
        .foregroundColor(theme.colors.primary)
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 4)
            .fill(theme.colors.primaryLowContrast)
        )
    }
}
