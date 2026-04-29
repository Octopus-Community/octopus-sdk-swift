//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Combine
import SwiftUI
import OctopusCore

struct ResponseActionBarView: View {
    @Environment(\.octopusTheme) private var theme

    let kind: ResponseKind
    let liveMeasuresPublisher: AnyPublisher<LiveMeasures, Never>
    let initialLiveMeasures: LiveMeasures
    let reactionTapped: (ReactionKind?) -> Void
    let openCreateReply: () -> Void

    @State private var liveMeasures: LiveMeasures

    init(kind: ResponseKind,
         liveMeasuresPublisher: AnyPublisher<LiveMeasures, Never>,
         initialLiveMeasures: LiveMeasures,
         reactionTapped: @escaping (ReactionKind?) -> Void,
         openCreateReply: @escaping () -> Void) {
        self.kind = kind
        self.liveMeasuresPublisher = liveMeasuresPublisher
        self.initialLiveMeasures = initialLiveMeasures
        self.reactionTapped = reactionTapped
        self.openCreateReply = openCreateReply
        self._liveMeasures = State(initialValue: initialLiveMeasures)
    }

    var body: some View {
        // Figma: `h-[44px] pt-[8px]` — 44pt tall with 8pt top padding. We keep the default
        // center alignment in the HStack: `ReactionToggleView` is ~44pt tall (its own tap
        // target) while the Reply button intrinsically sizes to its ~24pt content; centering
        // both inside the 44pt frame aligns their icons on the same visual line. `items-start`
        // in the Figma is a CSS artifact of a 1pt-height `Spacer` trick, not a hard alignment
        // requirement — matching visual alignment between the two button icons is more
        // important here.
        HStack(spacing: 16) {
            ReactionToggleView(
                likeNotSelectedImage: likeAssetForKind,
                userReaction: liveMeasures.userInteractions.reaction,
                reactionTapped: reactionTapped)

            if kind == .comment {
                Button(action: openCreateReply) {
                    CreateChildInteractionView(
                        image: theme.assets.icons.content.reply.creation.open,
                        text: "Content.AggregatedInfo.Answer",
                        kind: .reply)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            if !liveMeasures.aggregatedInfo.reactions.isEmpty {
                ReactionsSummary(
                    reactions: liveMeasures.aggregatedInfo.reactions,
                    countPlacement: .leading)
            }
        }
        // No outer `.padding(.top, ...)`: `ReactionToggleView` already has an internal
        // `.padding(.vertical, 10)` (its own 44pt tap target) which naturally supplies the
        // visual gap between the card's bottom and the Like icon. Adding an outer top padding
        // on top of that double-counts the space and visibly pushes the bar too far down.
        .frame(minHeight: 44)
        .onReceive(liveMeasuresPublisher) { liveMeasures = $0 }
        // Also react to `initialLiveMeasures` changes: the detail screen builds its
        // `ResponseViewData` from a static snapshot (the comment-detail view model doesn't
        // expose a publisher for the header comment, only `aggregatedInfo` + `userInteractions`),
        // so `liveMeasuresPublisher` is `Empty` in that case and only `initialLiveMeasures`
        // updates when the underlying comment changes. Without this, a tap on the like button
        // would fire the closure but the visible reaction state would stay stuck on the first
        // snapshot seen when the view was created.
        .onValueChanged(of: initialLiveMeasures) { liveMeasures = $0 }
    }

    /// Picks the correct "not-reacted" icon based on whether this is a comment or reply action bar.
    private var likeAssetForKind: UIImage {
        switch kind {
        case .comment: theme.assets.icons.content.comment.likeNotSelected
        case .reply:   theme.assets.icons.content.reply.likeNotSelected
        }
    }
}
