//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

struct PostAggregatedInfoView: View {
    @Environment(\.octopusTheme) private var theme

    let aggregatedInfo: AggregatedInfo
    let childrenTapped: () -> Void

    @State private var isShowingPopover = false

    @State private var animate = false

    init(aggregatedInfo: AggregatedInfo,
         childrenTapped: @escaping () -> Void) {
        self.aggregatedInfo = aggregatedInfo
        self.childrenTapped = childrenTapped
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                ReactionsSummary(reactions: aggregatedInfo.reactions, countPlacement: .trailing)
                Spacer()
                if aggregatedInfo.childCount > 0 {
                    Button(action: childrenTapped) {
                        AggregateView(image: theme.assets.icons.content.post.commentCount, count: aggregatedInfo.childCount)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabelInBundle("Accessibility.Comment.Count_count:\(aggregatedInfo.childCount)")
                }
                if aggregatedInfo.viewCount > 0 {
                    Button(action: { isShowingPopover = true }) {
                        AggregateView(image: theme.assets.icons.content.post.viewCount, count: aggregatedInfo.viewCount)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabelInBundle("Accessibility.View.Count_count:\(aggregatedInfo.viewCount)")
                    .modify {
                        if #available(iOS 16.4, *) {
                            $0.popover(isPresented: $isShowingPopover, arrowEdge: .bottom) {
                                Text("Content.AggregatedInfo.View.Explanation", bundle: .module)
                                    .font(theme.fonts.caption1)
                                    .foregroundColor(theme.colors.gray900)
                                    .padding(.horizontal)
                                    .presentationCompactAdaptation((.popover))
                            }
                        } else { $0 }
                    }
                }
            }.animation(.default, value: animate)
        }
        .onValueChanged(of: aggregatedInfo) { _ in
            animate = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                animate = false
            }
        }
    }
}

private struct AggregateView: View {
    @Environment(\.octopusTheme) private var theme

    let image: UIImage
    let count: Int

    var body: some View {
        HStack(spacing: 1) {
            IconImage(image)
                .scaleEffect(1.1)
                .accessibilityHidden(true)
            if count > 0 {
                Text(String.formattedCount(count))
                    .modify {
                        if #available(iOS 16.0, *) {
                            $0.contentTransition(.numericText())
                                .animation(.default, value: count)
                        } else {
                            $0
                        }
                    }
            }
        }
        .font(theme.fonts.caption1)
        .foregroundColor(theme.colors.gray700)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.vertical, 11)
        .frame(minWidth: 44)
        .modify {
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                $0.fixedSize()
            } else {
                $0
            }
        }
    }
}
