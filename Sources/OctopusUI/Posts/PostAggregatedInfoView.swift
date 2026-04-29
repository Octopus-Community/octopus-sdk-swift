//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

struct PostAggregatedInfoView: View {
    @Environment(\.octopusTheme) private var theme

    let aggregatedInfo: AggregatedInfo
    let reactionTapped: (ReactionKind?) -> Void
    let childrenTapped: () -> Void
    let viewCountTapped: () -> Void

    @State private var animate = false

    init(aggregatedInfo: AggregatedInfo,
         reactionTapped: @escaping (ReactionKind?) -> Void,
         childrenTapped: @escaping () -> Void,
         viewCountTapped: @escaping () -> Void) {
        self.aggregatedInfo = aggregatedInfo
        self.reactionTapped = reactionTapped
        self.childrenTapped = childrenTapped
        self.viewCountTapped = viewCountTapped
    }

    private var hasReactions: Bool {
        !aggregatedInfo.reactions.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AdaptiveAccessibleStack(hStackSpacing: 2, vStackAlignment: .leading, vStackSpacing: 0) {
                if hasReactions {
                    ReactionsSummary(
                        reactions: aggregatedInfo.reactions,
                        countPlacement: .trailing)
                } else {
                    ReactionPromptButton(reactionTapped: reactionTapped)
                }
                Spacer()
                countsView
            }
            .animation(.default, value: animate)
        }
        .onValueChanged(of: aggregatedInfo) { _ in
            animate = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                animate = false
            }
        }
    }

    private func commentCountKey(_ count: Int) -> LocalizedStringKey {
        let formatted = String.formattedCount(count)
        if count == 1 {
            return "Content.AggregatedInfo.CommentCount.One_count:\(formatted)"
        }
        return "Content.AggregatedInfo.CommentCount.Plural_count:\(formatted)"
    }

    private func viewCountKey(_ count: Int) -> LocalizedStringKey {
        let formatted = String.formattedCount(count)
        if count == 1 {
            return "Content.AggregatedInfo.ViewCount.One_count:\(formatted)"
        }
        return "Content.AggregatedInfo.ViewCount.Plural_count:\(formatted)"
    }

    @ViewBuilder
    private var countsView: some View {
        HStack(spacing: 4) {
            if aggregatedInfo.childCount > 0 {
                Button(action: childrenTapped) {
                    Text(commentCountKey(aggregatedInfo.childCount), bundle: .module)
                        .font(theme.fonts.caption1)
                        .fontWeight(.medium)
                        .foregroundColor(theme.colors.gray700)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabelInBundle(
                    "Accessibility.Comment.Count_count:\(aggregatedInfo.childCount)"
                )
            }
            if aggregatedInfo.childCount > 0,
               aggregatedInfo.viewCount > 0 {
                DotSeparator()
            }
            if aggregatedInfo.viewCount > 0 {
                Button(action: viewCountTapped) {
                    Text(viewCountKey(aggregatedInfo.viewCount), bundle: .module)
                        .font(theme.fonts.caption1)
                        .fontWeight(.medium)
                        .foregroundColor(theme.colors.gray700)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabelInBundle(
                    "Accessibility.View.Count_count:\(aggregatedInfo.viewCount)"
                )
            }
        }
    }
}

// MARK: - Private Views

private struct DotSeparator: View {
    @Environment(\.octopusTheme) private var theme

    var body: some View {
        Text(verbatim: "·")
            .font(theme.fonts.caption1)
            .fontWeight(.medium)
            .foregroundColor(theme.colors.gray700)
            .accessibilityHidden(true)
    }
}

// MARK: - Previews

private let previewStates: [(String, AggregatedInfo)] = [
    ("No reactions, no counts",
     .init(reactions: [], childCount: 0, viewCount: 0, pollResult: nil)),
    ("No reactions, views only",
     .init(reactions: [], childCount: 0, viewCount: 31, pollResult: nil)),
    ("No reactions, comments + views",
     .init(reactions: [], childCount: 42, viewCount: 1300, pollResult: nil)),
    ("Reactions + comments + views",
     .init(reactions: [
        .init(reactionKind: .heart, count: 120),
        .init(reactionKind: .joy, count: 50),
        .init(reactionKind: .mouthOpen, count: 22)
     ], childCount: 192, viewCount: 1300, pollResult: nil)),
    ("Reactions, no comments",
     .init(reactions: [.init(reactionKind: .heart, count: 5)],
           childCount: 0, viewCount: 540, pollResult: nil)),
    ("Large numbers",
     .init(reactions: [
        .init(reactionKind: .heart, count: 9500),
        .init(reactionKind: .clap, count: 3200)
     ], childCount: 15000, viewCount: 2_500_000, pollResult: nil))
]

#Preview("All States") {
    VStack(spacing: 0) {
        ForEach(Array(previewStates.enumerated()), id: \.offset) { _, state in
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: state.0)
                    .font(.caption)
                    .foregroundColor(.secondary)
                PostAggregatedInfoView(
                    aggregatedInfo: state.1,
                    reactionTapped: { _ in },
                    childrenTapped: {},
                    viewCountTapped: {})
            }
            .padding(.horizontal, 16)
            Divider()
        }
    }
}
