//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

struct AggregatedInfoView: View {
    @Environment(\.octopusTheme) private var theme

    let aggregatedInfo: AggregatedInfo
    let userInteractions: UserInteractions
    let minChildCount: Int?
    let childrenTapped: () -> Void
    let likeTapped: () -> Void

    @State private var isShowingPopover = false

    init(aggregatedInfo: AggregatedInfo, userInteractions: UserInteractions, minChildCount: Int? = nil,
         childrenTapped: @escaping () -> Void, likeTapped: @escaping () -> Void) {
        self.aggregatedInfo = aggregatedInfo
        self.userInteractions = userInteractions
        self.minChildCount = minChildCount
        self.childrenTapped = childrenTapped
        self.likeTapped = likeTapped
    }

    var childCount: Int {
        max(aggregatedInfo.childCount, minChildCount ?? 0)
    }

    var body: some View {
        HStack(spacing: 24) {
            Button(action: { isShowingPopover = true }) {
                AggregateView(image: .AggregatedInfo.view, count: aggregatedInfo.viewCount,
                              nullDisplayValue: "Content.AggregatedInfo.View")
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
                } else {
                    $0.disabled(true)
                }
            }

            Button(action: likeTapped) {
                AggregateView(image: userInteractions.hasLiked ? .AggregatedInfo.likeActivated : .AggregatedInfo.like,
                              imageForegroundColor: userInteractions.hasLiked ?
                              theme.colors.like : theme.colors.gray700,
                              count: aggregatedInfo.likeCount,
                              nullDisplayValue: "Content.AggregatedInfo.Like")
            }
            .buttonStyle(.plain)

            Button(action: childrenTapped) {
                AggregateView(image: .AggregatedInfo.comment, count: childCount,
                              nullDisplayValue: "Content.AggregatedInfo.Comment")
            }
            .buttonStyle(.plain)
        }
        .fixedSize()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AggregateView: View {
    @Environment(\.octopusTheme) private var theme

    let image: ImageResource
    let imageForegroundColor: Color?
    let count: Int
    let nullDisplayValue: LocalizedStringKey

    @State private var animate = false

    private var monospacedFont: Font {
        if #available(iOS 15.0, *) {
            normalFont.monospaced()
        } else {
            normalFont.monospacedDigit()
        }
    }

    private var normalFont: Font { theme.fonts.caption1 }

    init(image: ImageResource, imageForegroundColor: Color? = nil, count: Int, nullDisplayValue: LocalizedStringKey) {
        self.image = image
        self.imageForegroundColor = imageForegroundColor
        self.count = count
        self.nullDisplayValue = nullDisplayValue
    }

    var body: some View {
        HStack(spacing: 8) {
            // make sure the image has the same height as the text. To do that, use a squared font size based
            // transparent image and put our image on overlay of this transparent image
            Image(systemName: "square")
                .font(normalFont.weight(.medium))
                .foregroundColor(Color.clear)
                .overlay(
                    Image(image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .foregroundColor(imageForegroundColor ?? theme.colors.gray700)
                        .padding(-2) // make it slightly bigger
                        .scaleEffect(animate ? 1.4 : 1.0)
                        .opacity(animate ? 0.9 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.3), value: animate)
                )
            ZStack(alignment: .leading) {
                Text(verbatim: "0000") // biggest possible string
                    .font(monospacedFont)
                    .fontWeight(.medium)
                    .foregroundColor(Color.clear)
                Text(nullDisplayValue, bundle: .module) // biggest possible string
                    .font(normalFont)
                    .fontWeight(.medium)
                    .foregroundColor(Color.clear)
                if count > 0 {
                    Text(verbatim: "\(count)")
                        .font(monospacedFont)
                        .fontWeight(.medium)
                        .modify {
                            if #available(iOS 16.0, *) {
                                $0.contentTransition(.numericText())
                            } else {
                                $0
                            }
                        }
                        .animation(.default, value: count)

                } else {
                    Text(nullDisplayValue, bundle: .module)
                        .font(normalFont)
                        .fontWeight(.medium)
                }
            }
            .foregroundColor(theme.colors.gray700)
        }
        .onValueChanged(of: image) { newValue in
            animate = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                animate = false
            }
        }
    }
}
