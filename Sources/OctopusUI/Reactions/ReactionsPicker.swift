//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

struct PopoverReactionsBar: View {
    @Environment(\.octopusTheme) private var theme

    let reactions: [ReactionKind]
    let screenWidth: CGFloat
    let reactionTapped: (ReactionKind?) -> Void

    private let barHorizontalPadding: CGFloat = 12
    private let emojiSpacing: CGFloat = 4

    /// Cap emoji size so the bar fits within the screen width with some margin.
    private var maxEmojiSize: CGFloat? {
        guard screenWidth > 0, !reactions.isEmpty else { return nil }
        let margin: CGFloat = 32 // safety margin on each side
        let availableWidth = screenWidth - margin * 2
            - barHorizontalPadding * 2
            - emojiSpacing * CGFloat(reactions.count - 1)
        return max(availableWidth / CGFloat(reactions.count), 16)
    }

    var body: some View {
        HStack(spacing: emojiSpacing) {
            ForEach(reactions, id: \.self) { reaction in
                ReactionButton(
                    reaction: reaction,
                    maxSize: maxEmojiSize,
                    reactionTapped: reactionTapped)
            }
        }
        .padding(.horizontal, barHorizontalPadding)
        .background(
            Capsule()
                .fill(Color(.systemBackground))
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
                .aspectRatio(contentMode: .fit)
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
