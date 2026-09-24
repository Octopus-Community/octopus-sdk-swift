//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// The inline profile / activity tab selector: labels over a sliding underline.
///
/// Tabs are built on the shared ``ProfileTabsLayout`` box: they divide the row evenly when it has
/// width to spare, and fall back to their label's own width when it does not — in which case the row
/// scrolls horizontally. Either way the underline spans the selected tab edge to edge and its label
/// is centered on it by construction. The row shares its scroll offset with the pinned pill row that
/// replaces it once the header sticks — see ``SyncedTabsScrollView`` and ``ProfileStickyTabsHeader``.
struct CustomSegmentedControl: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.layoutDirection) private var layoutDirection

    let tabs: [LocalizedStringKey]
    @Binding var selectedTab: Int
    /// The scroll offset shared with the pinned pill row.
    @Binding var scrollOffset: CGFloat

    /// Lags `selectedTab` inside an animation, so the underline slides to its new tab.
    @State private var animatedSelectedTab: Int = 0
    /// Each tab's frame within the row, the underline's only source of geometry.
    @State private var tabFrames: [Int: CGRect] = [:]

    private let rowCoordinateSpace = "octopusProfileTabsRow"

    var body: some View {
        SyncedTabsScrollView(scrollOffset: $scrollOffset, selectedTab: selectedTab) {
            // `.bottom` rather than `.bottomLeading`: a centered horizontal alignment does not mirror
            // in RTL, so the underline always starts from the same place and only its offset has to
            // account for the layout direction.
            ZStack(alignment: .bottom) {
                HStack(spacing: ProfileTabsLayout.interTabSpacing) {
                    ForEach(tabs.indices, id: \.self) { index in
                        tab(index: index)
                    }
                }
                // Leave the underline its own band below the labels.
                .padding(.bottom, ProfileTabsLayout.underlineHeight)

                underline
            }
            .coordinateSpace(name: rowCoordinateSpace)
            .padding(.horizontal, ProfileTabsLayout.rowHorizontalPadding)
        }
        .onPreferenceChange(TabFramePreferenceKey.self) { tabFrames = $0 }
        .onAppear {
            animatedSelectedTab = selectedTab
        }
        .onValueChanged(of: selectedTab) { selectedTab in
            withAnimation(.spring(duration: 0.2)) {
                animatedSelectedTab = selectedTab
            }
        }
    }

    private func tab(index: Int) -> some View {
        Text(tabs[index], bundle: .module)
            .font(theme.fonts.caption1.weight(.semibold))
            .foregroundColor(selectedTab == index ? theme.colors.primary : theme.colors.gray700)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, ProfileTabsLayout.tabHorizontalPadding)
            .padding(.vertical, ProfileTabsLayout.tabVerticalPadding)
            // Flexible, so the tabs share the row when it has width to spare — the label stays
            // centered in its slot and the underline spans the whole of it. `fixedSize` on the label
            // keeps the tab's own width as the floor, so an overflowing row scrolls instead of
            // squeezing its labels.
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: TabFramePreferenceKey.self,
                        value: [index: geometry.frame(in: .named(rowCoordinateSpace))])
                }
            )
            // The id ScrollViewReader scrolls to on the OS versions that cannot share an offset.
            .id(index)
            .onTapGesture {
                selectedTab = index
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityValueInBundle(
                animatedSelectedTab == index ? "Accessibility.Common.Selected" : "Accessibility.Common.NotSelected")
    }

    /// The selected tab's underline, placed from the measured tab frames — starting from the row's
    /// horizontal centre, which is where the `ZStack`'s `.bottom` anchor puts it in both layout
    /// directions. See ``ProfileTabsLayout/underlineOffset(tabMidX:rowWidth:layoutDirection:)`` for
    /// why the offset is direction-dependent.
    @ViewBuilder
    private var underline: some View {
        if let frame = tabFrames[animatedSelectedTab], rowWidth > 0 {
            Rectangle()
                .frame(width: frame.width, height: ProfileTabsLayout.underlineHeight)
                .foregroundColor(theme.colors.primary)
                .offset(x: ProfileTabsLayout.underlineOffset(tabMidX: frame.midX, rowWidth: rowWidth,
                                                             layoutDirection: layoutDirection))
        }
    }

    /// Width of the tab row, i.e. the trailing edge of the last measured tab.
    private var rowWidth: CGFloat {
        tabFrames.values.map(\.maxX).max() ?? 0
    }
}

/// Collects every tab's frame, keyed by index.
private struct TabFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] { [:] }

    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
