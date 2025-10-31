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
            HStack {
                ReactionsSummary(reactions: aggregatedInfo.reactions, countPlacement: .trailing)
                .buttonStyle(.plain)
                Spacer()
                if aggregatedInfo.childCount > 0 {
                    Button(action: childrenTapped) {
                        AggregateView(image: .AggregatedInfo.comment, count: aggregatedInfo.childCount)
                    }
                    .buttonStyle(.plain)
                }
                if aggregatedInfo.viewCount > 0 {
                    Button(action: { isShowingPopover = true }) {
                        AggregateView(image: .AggregatedInfo.view, count: aggregatedInfo.viewCount)
                    }
                    .buttonStyle(.plain)
                    .modify {
                        if #available(iOS 16.4, *) {
                            $0.popover(isPresented: $isShowingPopover, arrowEdge: .bottom) {
                                Text("Content.AggregatedInfo.View.Explanation", bundle: .module)
                                    .font(theme.fonts.caption1)
                                    .foregroundColor(theme.colors.gray900)
                                    .padding(.horizontal)
                                    .presentationCompactAdaptation((.popover))
                            }
                        }
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

    let image: GenImageResource
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            // make sure the image has the same height as the text. To do that, use a squared font size based
            // transparent image and put our image on overlay of this transparent image
            Image(systemName: "square")
                .font(theme.fonts.caption1)
                .foregroundColor(Color.clear)
                .overlay(
                    Image(res: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .foregroundColor(theme.colors.gray700)
                        .padding(-2) // make it slightly bigger
                        .scaleEffect(1.0)
                        .opacity(1.0)
                )
            if count > 0 {
                Text(String.formattedCount(count))
                    .font(theme.fonts.caption1)
                    .foregroundColor(theme.colors.gray700)
                    .modify {
                        if #available(iOS 16.0, *) {
                            $0.contentTransition(.numericText())
                        } else {
                            $0
                        }
                    }
                    .animation(.default, value: count)
            }
        }
    }
}
