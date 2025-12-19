//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct AuthorAndDateHeaderView: View {
    @Environment(\.octopusTheme) private var theme

    let author: Author
    let relativeDate: String
    var topPadding: CGFloat = 0
    var bottomPadding: CGFloat = 0
    let displayProfile: (String) -> Void
    var displayContent: (() -> Void)? = nil

    var body: some View {
        AdaptiveAccessibleStack2Contents(
            hStackSpacing: 4,
            vStackAlignment: .leading, vStackSpacing: 0,
            horizontalContent: {
                authorView

                Circle()
                    .frame(width: 2, height: 2)
                    .foregroundColor(theme.colors.gray900)
                    .padding(.top, topPadding)
                    .padding(.bottom, bottomPadding)

                dateView
                    .layoutPriority(1)
            },
            verticalContent: {
                authorView
                dateView
            })
    }

    var authorView: some View {
        OpenProfileButton(author: author, displayProfile: displayProfile) {
            HStack(spacing: 0) {
                author.name.textView
                    .font(theme.fonts.body2)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.colors.gray900)
                    .multilineTextAlignment(.leading)

                if author.tags.contains(.admin) {
                    Text("Profile.Tag.Admin", bundle: .module)
                        .octopusBadgeStyle(.xs, status: .admin)
                        .padding(.leading, 4)
                        .fixedSize()
                } else {
                    GamificationLevelBadge(level: author.gamificationLevel, size: .small)
                        .fixedSize()
                }
            }
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
        }
    }

    var dateView: some View {
        ButtonOrContent(embedInButton: displayContent != nil, action: { displayContent?() }) {
            Text(relativeDate)
                .font(theme.fonts.caption1)
                .foregroundColor(theme.colors.gray500)
                .fixedSize()
                .lineLimit(1) // Always on one line
                .fixedSize()
                .layoutPriority(1) // Ensures it does not get pushed out
                .padding(.top, topPadding + 1)
                .padding(.bottom, bottomPadding + 1)
        }
        .buttonStyle(.plain)
    }
}
