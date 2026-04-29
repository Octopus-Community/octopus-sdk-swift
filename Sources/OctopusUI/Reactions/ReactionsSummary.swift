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

    @Compat.ScaledMetric(relativeTo: .caption1) private var reactionImageSize: CGFloat = 20

    var body: some View {
        HStack(spacing: 2) {
            if countPlacement == .leading {
                countView
            }
            HStack(spacing: -8) {
                ForEach(reactionsToDisplay, id: \.self) { reactionKind in
                    Image(uiImage: theme.assets.icons.content.reaction[reactionKind])
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: reactionImageSize, height: reactionImageSize)
                        .shadow(color: Color(UIColor.systemBackground), radius: 0, x: -1, y: 0)
                }
            }
            if countPlacement == .trailing {
                countView
            }
        }
        .font(theme.fonts.caption1)
        .padding(.vertical, 6)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabelInBundle("Accessibility.Reaction.Count_count:\(reactionsCount)")
    }

    var reactionsCount: Int {
        reactions.reduce(0, { $0 + $1.count })
    }

    var reactionsToDisplay: [ReactionKind] {
        reactions.filter { !$0.isEmpty }.prefix(maxReactionsKind).map(\.reactionKind)
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
