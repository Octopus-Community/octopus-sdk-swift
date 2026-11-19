//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import OctopusCore

/// The footer of a post, on one 44pt line: the like button with the total of reactions, the comment button with the
/// number of comments, then on the right the most used reactions, which open who reacted.
///
/// Every button reaches 8pt past its icon, inside its tap area, so that the icons stay on the screen's 16pt gutter
/// while each button keeps a 44 × 44pt tap area, even without a count.
struct PostActionBarView: View {
    @Environment(\.octopusTheme) private var theme

    let contentId: String
    let aggregatedInfo: AggregatedInfo
    let userReaction: UserReaction?
    let displayCommentButton: Bool
    let reactionTapped: (ReactionKind?) -> Void
    let commentTapped: () -> Void
    /// Needed by the "who reacted" sheet, which lists profiles and lets them be opened.
    let displayProfile: (_ profileId: String, _ clientUserId: String?) -> Void

    private var reactionCount: Int {
        aggregatedInfo.reactions.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        AdaptiveAccessibleStack(hStackSpacing: 0, vStackAlignment: .leading, vStackSpacing: 0) {
            HStack(spacing: 4) {
                ReactionToggleView(
                    likeNotSelectedImage: theme.assets.icons.content.post.likeNotSelected,
                    userReaction: userReaction,
                    caption: .count(reactionCount),
                    horizontalPadding: 8,
                    reactionTapped: reactionTapped)

                if displayCommentButton {
                    Button(action: {
                        HapticFeedback.play()
                        commentTapped()
                    }) {
                        CreateChildInteractionView(
                            image: theme.assets.icons.content.comment.creation.open,
                            caption: .count(aggregatedInfo.childCount),
                            kind: .comment)
                        .padding(.horizontal, 8)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    // "15 comments", or "Comment" while there is none.
                    .accessibilityLabelInBundle(
                        aggregatedInfo.childCount > 0
                            ? "Accessibility.Comment.Count_count:\(aggregatedInfo.childCount)"
                            : "Content.AggregatedInfo.Comment")
                }
            }

            Spacer(minLength: 0)

            ReactionsSummary(
                contentId: contentId,
                reactions: aggregatedInfo.reactions,
                layout: .mostUsedOnly,
                displayProfile: displayProfile)
        }
        .padding(.horizontal, theme.sizes.horizontalPadding - 8)
        .frame(minHeight: 44)
    }
}

// MARK: - Previews

// The member's own reaction cannot be built outside OctopusCore: the previews show the footer before any.
private let previewStates: [(String, AggregatedInfo, Bool)] = [
    ("Nothing yet",
     .init(reactions: [], childCount: 0, viewCount: 0, pollResult: nil), true),
    ("Reactions and comments",
     .init(reactions: [
        .init(reactionKind: .heart, count: 120),
        .init(reactionKind: .joy, count: 50),
        .init(reactionKind: .mouthOpen, count: 22)
     ], childCount: 15, viewCount: 1300, pollResult: nil), true),
    ("Large numbers",
     .init(reactions: [
        .init(reactionKind: .heart, count: 9500),
        .init(reactionKind: .clap, count: 2900)
     ], childCount: 1250, viewCount: 2_500_000, pollResult: nil), true),
    ("Comments closed",
     .init(reactions: [
        .init(reactionKind: .heart, count: 40),
        .init(reactionKind: .clap, count: 8)
     ], childCount: 0, viewCount: 31, pollResult: nil), false)
]

#Preview("All States") {
    VStack(spacing: 0) {
        ForEach(Array(previewStates.enumerated()), id: \.offset) { _, state in
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: state.0)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                PostActionBarView(
                    contentId: "preview-post",
                    aggregatedInfo: state.1,
                    userReaction: nil,
                    displayCommentButton: state.2,
                    reactionTapped: { _ in },
                    commentTapped: {},
                    displayProfile: { _, _ in })
            }
            Divider()
        }
    }
    .mockEnvironmentForPreviews()
}
