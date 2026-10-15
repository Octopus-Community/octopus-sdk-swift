//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct ContentSizedSheet<Content: View, ScrollingContent: View>: View {
    @Environment(\.verticalSizeClass) private var vSize
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.octopusTheme) private var theme

    @ViewBuilder var content: Content
    @ViewBuilder var scrollingContent: ScrollingContent

    @State private var contentHeight: CGFloat = .zero
    /// Height of the window hosting the sheet, `0` until it is known.
    @State private var windowHeight: CGFloat = .zero

    var body: some View {
        ZStack {
            if #available(iOS 16.0, *) {
                let scrolls = ContentSizedSheetLayout.scrolls(contentHeight: contentHeight,
                                                              windowHeight: windowHeight,
                                                              fallbackWindowHeight: provisionalWindowHeight)
                VStack { // Ensures the content wraps its natural height
                    content
                        .readHeight($contentHeight)
                        .opacity(scrolls ? 0 : 1) // Hide if scrolling is needed
                }
                .frame(height: ContentSizedSheetLayout.height(contentHeight: contentHeight,
                                                              windowHeight: windowHeight,
                                                              fallbackWindowHeight: provisionalWindowHeight))
                .overlay(
                    scrollingContent
                        .opacity(scrolls ? 1 : 0) // Enable scrolling only if needed
                )
            } else {
                scrollingContent
            }
            if vSize == .compact {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            IconImage(theme.assets.icons.common.close)
                                .font(theme.fonts.title2)
                                .foregroundColor(theme.colors.gray900)
                                .padding(12)
                        }
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                        .buttonStyle(.plain)
                        .accessibilityLabelInBundle("Common.Close")
                    }
                    Spacer()
                }
                .padding(.top, 16)
            }
        }
        .readWindowHeight($windowHeight)
    }
}

/// Sizing of a ``ContentSizedSheet``, apart from the generic view so it can be tested.
enum ContentSizedSheetLayout {
    /// Share of the window height the sheet can take before its content scrolls.
    static let maxHeightRatio: CGFloat = 0.8

    /// Height of the sheet: the content's natural height, capped at ``maxHeightRatio`` of the window.
    static func height(contentHeight: CGFloat, windowHeight: CGFloat, fallbackWindowHeight: CGFloat) -> CGFloat {
        guard let maxHeight = maxHeight(windowHeight: windowHeight, fallbackWindowHeight: fallbackWindowHeight) else {
            return contentHeight
        }
        return min(contentHeight, maxHeight)
    }

    /// Whether the content is taller than the cap, so the scrolling variant is shown instead.
    static func scrolls(contentHeight: CGFloat, windowHeight: CGFloat, fallbackWindowHeight: CGFloat) -> Bool {
        guard let maxHeight = maxHeight(windowHeight: windowHeight, fallbackWindowHeight: fallbackWindowHeight) else {
            return false
        }
        return contentHeight > maxHeight
    }

    /// The cap, `nil` when no height is known at all. While the window height is unknown (zero),
    /// `fallbackWindowHeight` stands in for it, so the first pass never asks the system for an uncapped detent; a
    /// zero height is never turned into a zero cap, which would show an empty, scrolling sheet.
    private static func maxHeight(windowHeight: CGFloat, fallbackWindowHeight: CGFloat) -> CGFloat? {
        let window = resolvedWindowHeight(measured: windowHeight, fallback: fallbackWindowHeight)
        guard window > 0 else { return nil }
        return window * maxHeightRatio
    }
}
