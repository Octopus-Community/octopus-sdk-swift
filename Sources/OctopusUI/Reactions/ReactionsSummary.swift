//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

struct ReactionsSummary: View {
    enum CountPlacement {
        case leading
        case trailing
    }

    let reactions: [ReactionCount]
    let countPlacement: CountPlacement
    var maxReactionsKind: Int = 3

    @State private var displayReactionsCount = false

    var body: some View {
        if reactionsCount > 0 {
            if #available(iOS 16.0, *) {
                Button(action: { displayReactionsCount = true }) {
                    ContentView(reactions: reactions, countPlacement: countPlacement, maxReactionsKind: maxReactionsKind)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHintInBundle("Accessibility.Reaction.Summary.SeeAll")
                .sheet(isPresented: $displayReactionsCount) {
                    ReactionsCountSheetScreen(reactions: reactions)
                        .accessibilityFocusOnAppear()
                        .accessibilityAddTraits(.isModal)
                }
            } else {
                ContentView(reactions: reactions, countPlacement: countPlacement, maxReactionsKind: maxReactionsKind)
            }
        } else {
            EmptyView()
        }
    }

    var reactionsCount: Int {
        reactions.reduce(0, { $0 + $1.count })
    }
}

private struct ContentView: View {

    @Environment(\.octopusTheme) private var theme

    let reactions: [ReactionCount]
    let countPlacement: ReactionsSummary.CountPlacement
    let maxReactionsKind: Int

    var body: some View {
        HStack(spacing: 2) {
            if countPlacement == .leading {
                countView
                    .frame(minWidth: 10) // fix a weird bug in the CommentDetailView where the layout is broken
            }
            HStack(spacing: -5) {
                ForEach(reactionsToDisplay, id: \.self) { reactionKind in
                    Text(reactionKind.unicode)
                        .shadow(color: Color(UIColor.systemBackground), radius: 0, x: -1, y: 0)
                }
            }
            if countPlacement == .trailing {
                countView
                    .frame(minWidth: 10) // fix a weird bug in the CommentDetailView where the layout is broken
            }
        }
        .font(theme.fonts.caption1)
        .padding(.vertical, 14)
        .frame(minWidth: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabelInBundle("Accessibility.Reaction.Count_count:\(reactionsCount)")
    }

    var reactionsCount: Int {
        reactions.reduce(0, { $0 + $1.count })
    }

    var reactionsToDisplay: [ReactionKind] {
        reactions.filter { $0.count > 0 }.prefix(maxReactionsKind).map(\.reactionKind)
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
