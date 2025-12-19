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

    var body: some View {
        ZStack {
            if #available(iOS 16.0, *) {
                VStack { // Ensures the content wraps its natural height
                    content
                        .readHeight($contentHeight)
                        .opacity(contentHeight <= UIScreen.main.bounds.height * 0.8 ? 1 : 0) // Hide if scrolling is needed
                }
                .frame(height: min(contentHeight, UIScreen.main.bounds.height * 0.8)) // Limit height
                .overlay(
                    scrollingContent
                        .opacity(contentHeight > UIScreen.main.bounds.height * 0.8 ? 1 : 0) // Enable scrolling only if needed
                )
            } else {
                scrollingContent
            }
            if vSize == .compact {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Image(systemName: "xmark")
                                .font(theme.fonts.title2.weight(.semibold))
                                .padding(12)
                                .foregroundColor(theme.colors.gray900)
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
    }
}
