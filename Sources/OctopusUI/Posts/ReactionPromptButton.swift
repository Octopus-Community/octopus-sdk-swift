//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import OctopusCore

/// "Be the first to react" prompt. Tapping opens the reaction picker popover
/// anchored to the prompt (centered on screen, 12pt above the trigger).
///
/// Mirrors the picker-trigger pattern from `ReactionToggleView` but with a
/// plain tap gesture (no heart-toggle, no long-press) so users go straight to
/// the 6-reaction picker — matching the prompt's "pick a reaction" semantics.
struct ReactionPromptButton: View {
    @Environment(\.octopusTheme) private var theme

    let reactionTapped: (ReactionKind?) -> Void

    @State private var showReactionPicker = false
    @State private var screenWidth: CGFloat = .zero

    var body: some View {
        Button(action: { showReactionPicker = true }) {
            Text("Content.AggregatedInfo.ReactionCount.Empty", bundle: .module)
                .font(theme.fonts.caption1)
                .foregroundColor(theme.colors.gray700)
                .padding(.vertical, 6)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .readScreenWidth($screenWidth)
        .displayableOverlay(
            isPresented: $showReactionPicker,
            horizontalPadding: 12,
            verticalPadding: 12
        ) {
            PopoverReactionsBar(
                reactions: ReactionKind.knownValues,
                screenWidth: screenWidth,
                reactionTapped: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showReactionPicker = false
                    }
                    reactionTapped($0)
                })
        }
    }
}

// MARK: - Previews

#Preview("Default") {
    ReactionPromptButton(reactionTapped: { _ in })
        .padding()
}
