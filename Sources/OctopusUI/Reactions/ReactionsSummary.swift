//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

struct ReactionsSummary: View {
    @Environment(\.textTone) private var textTone
    enum CountPlacement {
        case leading
        case trailing
    }

    enum Layout {
        /// The first reactions next to their total: the comment and reply footers.
        case withCount(CountPlacement)
        /// The most used reactions alone: the post footer, which shows the total on its like button. 8pt inside the
        /// tap area keep the last reaction on the screen's gutter.
        case mostUsedOnly
    }

    let contentId: String
    let reactions: [ReactionCount]
    let layout: Layout
    let displayProfile: (_ profileId: String, _ clientUserId: String?) -> Void
    var maxReactionsKind: Int = 3

    @State private var displayReactionsCount = false

    var body: some View {
        if reactionsCount > 0 {
            if #available(iOS 16.0, *) {
                Button(action: { displayReactionsCount = true }) {
                    ContentView(reactions: reactions, layout: layout, maxReactionsKind: maxReactionsKind)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHintInBundle(textTone.key(formal: "Accessibility.Reaction.Summary.SeeAll.Formal",
                                                        informal: "Accessibility.Reaction.Summary.SeeAll.Informal"))
                .octopusSheet(isPresented: $displayReactionsCount) {
                    ReactionsListSheetScreen(
                        contentId: contentId, reactions: reactions, displayProfile: displayProfile)
                        .accessibilityFocusOnAppear()
                        .accessibilityAddTraits(.isModal)
                }
            } else {
                ContentView(reactions: reactions, layout: layout, maxReactionsKind: maxReactionsKind)
            }
        } else {
            EmptyView()
        }
    }

    var reactionsCount: Int {
        reactions.reduce(0, { $0 + $1.count })
    }

    /// The `max` reactions with the highest counts, most used first. A tie keeps the order of `reactions`.
    /// Pure, so callable from any thread despite the main-actor isolation of `View`.
    nonisolated static func mostUsed(_ reactions: [ReactionCount], max: Int) -> [ReactionKind] {
        reactions.filter { !$0.isEmpty }
            .enumerated()
            .sorted { $0.element.count != $1.element.count ? $0.element.count > $1.element.count : $0.offset < $1.offset }
            .prefix(max)
            .map(\.element.reactionKind)
    }
}

private struct ContentView: View {

    @Environment(\.octopusTheme) private var theme

    let reactions: [ReactionCount]
    let layout: ReactionsSummary.Layout
    let maxReactionsKind: Int

    @Compat.ScaledMetric(relativeTo: .caption1) private var reactionImageSize: CGFloat = 20

    var body: some View {
        HStack(spacing: 2) {
            if case .withCount(.leading) = layout {
                countView
            }
            HStack(spacing: -8) {
                ForEach(reactionsToDisplay, id: \.self) { reactionKind in
                    Image(uiImage: theme.assets.icons.content.reaction[reactionKind])
                        .resizable()
                        .scaledToFit()
                        .frame(width: reactionImageSize, height: reactionImageSize)
                        .shadow(color: theme.colors.background, radius: 0, x: -1, y: 0)
                }
            }
            if case .withCount(.trailing) = layout {
                countView
            }
        }
        .font(theme.fonts.caption1)
        .padding(.vertical, 6)
        .padding(.trailing, trailingPadding)
        // Trailing: a single reaction, narrower than the tap area, stays on the gutter like three would.
        .frame(minWidth: 44, minHeight: 44, alignment: layoutAlignment)
        .accessibilityElement(children: .ignore)
        .accessibilityLabelInBundle("Accessibility.Reaction.Count_count:\(reactionsCount)")
    }

    var reactionsCount: Int {
        reactions.reduce(0, { $0 + $1.count })
    }

    private var layoutAlignment: Alignment {
        switch layout {
        case .withCount: .center
        case .mostUsedOnly: .trailing
        }
    }

    private var trailingPadding: CGFloat {
        switch layout {
        case .withCount: 0
        case .mostUsedOnly: 8
        }
    }

    var reactionsToDisplay: [ReactionKind] {
        switch layout {
        case .withCount:
            reactions.filter { !$0.isEmpty }.prefix(maxReactionsKind).map(\.reactionKind)
        case .mostUsedOnly:
            ReactionsSummary.mostUsed(reactions, max: maxReactionsKind)
        }
    }

    var countView: some View {
        Text(String.formattedCount(reactionsCount))
            .foregroundColor(theme.colors.gray700)
            .modify {
                if #available(iOS 16.0, *) {
                    $0.contentTransition(.numericText())
                } else {
                    $0
                }
            }
            .animation(.default, value: reactionsCount)
    }
}
