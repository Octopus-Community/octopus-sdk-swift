//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

/// Row of dots showing where the user is in a carousel.
struct PageIndicatorView: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let state: PageIndicatorState

    private enum Dimensions {
        static let normalDot: CGFloat = 6
        static let smallDot: CGFloat = 4
        static let spacing: CGFloat = 4
    }

    private enum Durations {
        static let selection: Double = 0.2
        /// Short, like the window of other apps' carousels: it follows the swipe of the photo, it must not lag behind.
        static let slide: Double = 0.12
    }

    var body: some View {
        // One dot per page, the pages outside the window shrunk to nothing: when the window moves, the dot leaving it
        // shrinks while the one entering grows, which slides the row by one dot.
        HStack(spacing: 0) {
            let selectedPage = state.firstPage + state.selectedPosition
            ForEach(Array(0..<state.pageCount), id: \.self) { page in
                let dot = state.dot(forPage: page)
                Circle()
                    .fill(page == selectedPage ? theme.colors.primary : theme.colors.gray300)
                    // The colours cross-fade, at their own pace, whether the window slides or not.
                    .animation(.easeInOut(duration: Durations.selection), value: selectedPage)
                    .frame(width: diameter(of: dot), height: diameter(of: dot))
                    .padding(.horizontal, dot == nil ? 0 : Dimensions.spacing / 2)
                    .opacity(dot == nil ? 0 : 1)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: Durations.slide), value: state)
        // The carousel owns the accessibility of the page position.
        .accessibilityHidden(true)
    }

    private func diameter(of dot: PageIndicatorState.Dot?) -> CGFloat {
        switch dot {
        case .normal: Dimensions.normalDot
        case .small: Dimensions.smallDot
        case nil: 0
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        if let state = PageIndicatorState.make(pageCount: 3, currentIndex: 1, lastMoveForward: true) {
            PageIndicatorView(state: state)
        }
        if let state = PageIndicatorState.make(pageCount: 8, currentIndex: 5, lastMoveForward: true) {
            PageIndicatorView(state: state)
        }
    }
    .padding()
    .mockEnvironmentForPreviews()
}
