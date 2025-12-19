//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

struct GamificationLevelBadge: View {
    @Environment(\.octopusTheme) private var theme

    enum Size {
        case small
        case big
    }
    let level: GamificationLevel?
    let size: Size

    @State private var textHeight: CGFloat = 1

    var body: some View {
        if let level, let gamificationBadgeColor = level.badgeColor, let textColor = level.badgeTextColor {
            switch size {
            case .big:
                HStack(spacing: 0) {
                    Text(verbatim: "\(level.name)")
                        .font(theme.fonts.caption1)
                        .fontWeight(.medium)
                        .readHeight($textHeight)
                    Image(res: .Gamification.badge)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: textHeight)
                        .accessibilityHidden(true)
                }
                .foregroundColor(textColor.color)
                .padding(.vertical, 1)
                .padding(.leading, 8)
                .padding(.trailing, 1)
                .background(
                    Capsule()
                        .fill(gamificationBadgeColor.color)
                )
            case .small:
                Image(res: .Gamification.badge)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(gamificationBadgeColor.color)
                    .accessibilityLabelCompat(level.name)
            }
        } else {
            EmptyView()
        }


    }
}
