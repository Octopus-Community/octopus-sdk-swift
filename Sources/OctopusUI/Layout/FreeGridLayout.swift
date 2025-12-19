//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

@available(iOS 16.0, *)
struct FreeGridLayout: Layout {

    var alignment: Alignment = .center

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }

        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0

        for size in sizes {
            if lineWidth + size.width > proposal.width ?? 0 {
                totalHeight += lineHeight
                lineWidth = size.width
                lineHeight = size.height
            } else {
                lineWidth += size.width
                lineHeight = max(lineHeight, size.height)
            }

            totalWidth = max(totalWidth, lineWidth)
        }

        totalHeight += lineHeight

        return .init(width: totalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let subviewsAndSizes = subviews.map { ($0, $0.sizeThatFits(.unspecified)) }

        var currentLineSize: CGFloat = 0

        // build lines
        var subviewsByLines = [[(Subviews.Element, CGSize)]]()
        var currentLine = [(Subviews.Element, CGSize)]()
        for (subview, size) in subviewsAndSizes {
            if currentLineSize + size.width > (proposal.width ?? bounds.width) {
                if !currentLine.isEmpty {
                    subviewsByLines.append(currentLine)
                }
                currentLine = []
                currentLineSize = 0
            }

            currentLine.append((subview, size))

            currentLineSize += size.width
        }
        // add remaining views
        if !currentLine.isEmpty {
            subviewsByLines.append(currentLine)
        }

        var lineX = bounds.minX
        var lineY = bounds.minY

        for line in subviewsByLines {
            let lineWidth = line.reduce(into: 0) { $0 += $1.1.width }
            let leadingGap = alignment == .center ? ((bounds.width) - lineWidth) / 2 : 0
            for (subview, size) in line {
                subview.place(
                    at: .init(
                        x: lineX + leadingGap + size.width / 2,
                        y: lineY + size.height / 2
                    ),
                    anchor: .center,
                    proposal: ProposedViewSize(size)
                )

                lineX += size.width
            }

            lineY += line.max { $0.1.height > $1.1.height }?.1.height ?? 0
            lineX = bounds.minX
        }
    }
}

