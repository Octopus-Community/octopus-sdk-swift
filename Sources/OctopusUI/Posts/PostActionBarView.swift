//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import OctopusCore

struct PostActionBarView: View {
    @Environment(\.octopusTheme) private var theme

    let userReaction: UserReaction?
    let reactionTapped: (ReactionKind?) -> Void
    let commentTapped: () -> Void

    var body: some View {
        AdaptiveAccessibleStack(
            hStackSpacing: 16,
            vStackSpacing: 0
        ) {
            ReactionToggleView(
                likeNotSelectedImage: theme.assets.icons.content.post.likeNotSelected,
                userReaction: userReaction,
                reactionTapped: reactionTapped)
            .frame(maxWidth: .infinity)

            Button(action: {
                HapticFeedback.play()
                commentTapped()
            }) {
                CreateChildInteractionView(
                    image: theme.assets.icons.content.comment.creation.open,
                    text: "Content.AggregatedInfo.Comment",
                    kind: .comment)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }
    }
}
