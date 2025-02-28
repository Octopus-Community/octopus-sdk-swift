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
        HStack(spacing: 4) {
            AggregateView(image: .AggregatedInfo.view, count: aggregatedInfo.viewCount, nullDisplayValue: "-")

            Button(action: likeTapped) {
                AggregateView(image: userInteractions.hasLiked ? .AggregatedInfo.likeActivated : .AggregatedInfo.like,
                              imageForegroundColor: userInteractions.hasLiked ?
                              theme.colors.like : theme.colors.gray500,
                              count: aggregatedInfo.likeCount,
                              nullDisplayValue: "")
            }

            Button(action: childrenTapped) {
                AggregateView(image: .AggregatedInfo.comment, count: childCount, nullDisplayValue: "-")
            }
        }
        .fixedSize()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AggregateView: View {
    @Environment(\.octopusTheme) private var theme

    let image: ImageResource
    let imageForegroundColor: Color?
    let count: Int
    let nullDisplayValue: String

    init(image: ImageResource, imageForegroundColor: Color? = nil, count: Int, nullDisplayValue: String) {
        self.image = image
        self.imageForegroundColor = imageForegroundColor
        self.count = count
        self.nullDisplayValue = nullDisplayValue
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(imageForegroundColor ?? theme.colors.gray500)
            ZStack(alignment: .leading) {
                Text(verbatim: "0000") // biggest possible string
                    .fontWeight(.medium)
                    .foregroundColor(Color.clear)
                Text(count > 0 ? "\(count)" : nullDisplayValue)
                    .fontWeight(.medium)
            }
            .modify {
                if #available(iOS 15.0, *) {
                    $0.font(theme.fonts.caption1.monospaced())
                } else {
                    $0.font(theme.fonts.caption1.monospacedDigit())
                }
            }
            .foregroundColor(theme.colors.gray500)
        }
    }
}
