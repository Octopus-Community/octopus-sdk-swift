//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

@available(iOS 16.0, *)
struct ReactionsCountSheetScreen: View {
    let reactions: [ReactionCount]
    @State private var detentHeight: CGFloat = 50

    var body: some View {
        ContentSizedSheet(
            content: { ReactionsCountView(reactions: reactions) },
            scrollingContent: { ReactionsCountView(reactions: reactions) }
        )
        .sizedSheet()
    }
}

@available(iOS 16.0, *)
struct ReactionsCountView: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.presentationMode) private var presentationMode

    let reactions: [ReactionCount]

    var body: some View {
        FreeGridLayout(alignment: .leading) {
            ForEach(reactions.filter { $0.count > 0 }, id: \.self) { reaction in
                HStack(spacing: 0) {
                    Text(reaction.reactionKind.unicode)
                    Text(String.formattedCount(reaction.count))
                }
                .font(theme.fonts.caption1.weight(.medium))
                .foregroundColor(theme.colors.gray700)
                .padding(.horizontal, 12)
                .accessibilityElement(children: .ignore)
                .accessibilityLabelInBundle("Accessibility.Reaction.Count_reaction:\(reaction.reactionKind.accessibilityValue)_count:\(reaction.count)")
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 35)
        .padding(.bottom, 20)
    }
}
