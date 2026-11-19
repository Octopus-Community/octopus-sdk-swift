//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

struct PopoverReactionsBar: View {
    @Environment(\.octopusTheme) private var theme

    let reactions: [ReactionKind]
    /// Width the bar can span: the width of the window's safe area, which excludes a camera on a side edge.
    let availableWidth: CGFloat
    let reactionTapped: (ReactionKind?) -> Void

    static let barHorizontalPadding: CGFloat = 12
    static let emojiSpacing: CGFloat = 4

    /// Cap emoji size so the bar fits within the available width with some margin.
    private var maxEmojiSize: CGFloat? {
        Self.maxEmojiSize(availableWidth: availableWidth, reactionCount: reactions.count)
    }

    /// Largest emoji size that keeps a bar of `reactionCount` emojis within `availableWidth`, margins included;
    /// `nil` while the width is unknown.
    static func maxEmojiSize(availableWidth: CGFloat, reactionCount: Int) -> CGFloat? {
        guard availableWidth > 0, reactionCount > 0 else { return nil }
        let margin: CGFloat = 32 // safety margin on each side
        let emojisWidth = availableWidth - margin * 2
            - barHorizontalPadding * 2
            - emojiSpacing * CGFloat(reactionCount - 1)
        return max(emojisWidth / CGFloat(reactionCount), 16)
    }

    var body: some View {
        HStack(spacing: Self.emojiSpacing) {
            ForEach(reactions, id: \.self) { reaction in
                ReactionButton(
                    reaction: reaction,
                    maxSize: maxEmojiSize,
                    reactionTapped: reactionTapped)
            }
        }
        .padding(.horizontal, Self.barHorizontalPadding)
        .background(
            Capsule()
                .fill(theme.colors.background)
                .overlay(Capsule().stroke(theme.colors.gray300, lineWidth: 1))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
        .accessibilityFocusOnAppear()
    }
}

private struct ReactionButton: View {
    @Environment(\.octopusTheme) private var theme

    let reaction: ReactionKind
    let maxSize: CGFloat?
    let reactionTapped: (ReactionKind?) -> Void

    @Compat.ScaledMetric(relativeTo: .largeTitle) private var emojiSize: CGFloat = 44
    @State private var animate = false

    private var effectiveSize: CGFloat {
        if let maxSize { return min(emojiSize, maxSize) }
        return emojiSize
    }

    var body: some View {
        Button(action: {
            animate = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                animate = false
            }
            reactionTapped(reaction)
        }) {
            Image(uiImage: theme.assets.icons.content.reaction[reaction])
                .resizable()
                .scaledToFit()
                .frame(width: effectiveSize, height: effectiveSize)
                .scaleEffect(animate ? 1.4 : 1.0)
                .opacity(animate ? 0.9 : 1.0)
                .animation(
                    .spring(response: 0.2, dampingFraction: 0.3),
                    value: animate)
                .padding(.vertical, 4)
        }
        .accessibilityLabelInBundle(reaction.labelKey)
        .hapticFeedback(trigger: animate) { oldValue, newValue in
            guard oldValue != newValue, newValue else { return false }
            return true
        }
    }
}
