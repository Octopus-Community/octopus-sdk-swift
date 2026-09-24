//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// A horizontally scrolling tab row whose scroll offset is shared with its peer row.
///
/// The profile screens show the same tabs twice: inline in the scrolled content, and pinned as glass
/// pills once the header sticks. A row that does not fit keeps its labels at their natural width and
/// scrolls rather than squeezing them, so the two rows must scroll together — otherwise the pills and
/// the tabs they cover drift apart.
///
/// A row that does fit is stretched to the viewport, which its flexible tabs then divide between
/// them. That is the common case: at three tabs the row very nearly fills an iPhone in French, and
/// only overflows in verbose languages or at large Dynamic Type sizes. Such a row does not scroll at
/// all — `scrollBounceBehavior(.basedOnSize)` takes the rubber-band away when there is nothing to
/// scroll to (iOS 16.4+; below that the row still bounces, harmlessly, back into place).
///
/// How the rows stay in sync depends on what the OS offers, hence a Compat wrapper rather than
/// `@available` checks spread through the two row views:
/// - **iOS 18+** — an exact two-way offset sync (`ScrollPosition` + `onScrollGeometryChange`).
/// - **iOS 14–17** — no settable offset, so each row anchors on the selected tab instead: enough to
///   keep the selected tab visible on both.
/// - **iOS 13** — no `ScrollViewReader`: a plain scroll view. Both rows start at the same end and
///   only diverge if the user scrolls one of them by hand.
///
/// Every version that can scroll programmatically (14+) also brings the selected tab fully into view
/// when the selection changes, so picking the last tab of an overflowing row never leaves it clipped.
struct SyncedTabsScrollView<Content: View>: View {
    /// The offset shared with the peer row. Both rows bind to the same `@State` on their host screen.
    @Binding var scrollOffset: CGFloat
    /// The tab to keep in view on the OS versions that cannot share an offset.
    let selectedTab: Int
    @ViewBuilder let content: Content

    /// Width of the scroll view itself: the row is stretched out to it rather than scrolled whenever
    /// it would otherwise be narrower.
    @State private var viewportWidth: CGFloat = 0

    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                OffsetSyncedTabsScrollView(scrollOffset: $scrollOffset, selectedTab: selectedTab,
                                           viewportWidth: viewportWidth) {
                    content
                }
            } else if #available(iOS 14.0, *) {
                SelectionAnchoredTabsScrollView(selectedTab: selectedTab, viewportWidth: viewportWidth) {
                    content
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    content.stretchedToViewport(viewportWidth)
                }
            }
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onValueChanged(of: geometry.size.width, initial: true) { viewportWidth = $0 }
            }
        )
    }
}

private extension View {
    /// Stretches a row narrower than the viewport out to it, so its flexible tabs can divide the
    /// width between them; leaves a wider row untouched, for the scroll view to scroll.
    func stretchedToViewport(_ viewportWidth: CGFloat) -> some View {
        frame(minWidth: viewportWidth)
    }

    /// Lets the row bounce only when it actually has somewhere to scroll. Paired with
    /// `stretchedToViewport`, which makes a fitting row exactly viewport-wide, this leaves a row that
    /// fits completely inert under the finger.
    @ViewBuilder
    func bouncesOnlyWhenScrollable() -> some View {
        if #available(iOS 16.4, *) {
            scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        } else {
            self
        }
    }
}

/// What a row reports about its own scrolling: where it currently is, and how far it can go.
@available(iOS 18.0, *)
private struct ScrollMetrics: Equatable {
    /// The physical horizontal content offset.
    let offset: CGFloat
    /// The largest offset the row can reach, i.e. how much its content overflows the viewport.
    let maxOffset: CGFloat

    init(_ geometry: ScrollGeometry) {
        offset = geometry.contentOffset.x
        maxOffset = max(geometry.contentSize.width - geometry.containerSize.width, 0)
    }
}

/// iOS 18+: the offset is both readable (`onScrollGeometryChange`) and settable (`ScrollPosition`),
/// so the two rows share it exactly.
@available(iOS 18.0, *)
private struct OffsetSyncedTabsScrollView<Content: View>: View {
    /// Sub-point differences are ignored in both directions, so the two rows correcting each other
    /// cannot ping-pong on rounding noise.
    private static var tolerance: CGFloat { 0.5 }

    @Environment(\.layoutDirection) private var layoutDirection

    @Binding var scrollOffset: CGFloat
    let selectedTab: Int
    let viewportWidth: CGFloat
    @ViewBuilder let content: Content

    @State private var position = ScrollPosition()
    /// What this row is actually showing, so an incoming change can be told apart from the echo of
    /// our own scrolling.
    @State private var ownOffset: CGFloat = 0
    /// How far this row can scroll, needed to convert a physical offset for `scrollTo(x:)` in RTL.
    @State private var maxOffset: CGFloat = 0

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            content.stretchedToViewport(viewportWidth)
        }
        .bouncesOnlyWhenScrollable()
        .scrollPosition($position)
        .onScrollGeometryChange(for: ScrollMetrics.self) { ScrollMetrics($0) } action: { _, metrics in
            ownOffset = metrics.offset
            maxOffset = metrics.maxOffset
            guard abs(scrollOffset - metrics.offset) > Self.tolerance else { return }
            scrollOffset = metrics.offset
        }
        // `initial: true` matters as much as the updates: the pinned row is created only once the
        // header sticks, so it never sees the offset *change* — it has to adopt the current one when
        // it appears, or it would show up scrolled back to the start.
        .onValueChanged(of: scrollOffset, initial: true) { newOffset in
            guard abs(ownOffset - newOffset) > Self.tolerance else { return }
            // `contentOffset.x` is physical, `scrollTo(x:)` counts from the reading direction's start.
            // The two agree in LTR and are opposite in RTL, so the shared (physical) offset has to be
            // flipped there — otherwise the peer row lands mirrored instead of aligned.
            position.scrollTo(x: layoutDirection == .rightToLeft ? maxOffset - newOffset : newOffset)
        }
        // The resulting offset flows back out through `onScrollGeometryChange`, so the peer row
        // follows along and both stay on the same tab.
        .onValueChanged(of: selectedTab) { selectedTab in
            withAnimation {
                position.scrollTo(id: selectedTab, anchor: .center)
            }
        }
    }
}

/// iOS 14–17: the offset cannot be set, so the rows agree on the selected tab instead of on an
/// offset — enough to keep the selected tab visible on both.
@available(iOS 14.0, *)
private struct SelectionAnchoredTabsScrollView<Content: View>: View {
    let selectedTab: Int
    let viewportWidth: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal, showsIndicators: false) {
                content.stretchedToViewport(viewportWidth)
            }
            .bouncesOnlyWhenScrollable()
            .onAppear {
                // One run loop later: on appear the row has not been laid out yet, so scrolling now
                // would be a no-op.
                DispatchQueue.main.async {
                    reader.scrollTo(selectedTab, anchor: .center)
                }
            }
            .onValueChanged(of: selectedTab) { selectedTab in
                withAnimation {
                    reader.scrollTo(selectedTab, anchor: .center)
                }
            }
        }
    }
}
