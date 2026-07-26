//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

/// The pinned (scrolled) profile tab selector, rendered as Instagram-style floating "pills":
/// each category is a capsule that, on iOS 26, uses liquid glass — tinted for the selected one —
/// so the pills float over the blurred content scrolling under the translucent nav bar. Pre-iOS 26
/// falls back to solid capsules on an opaque bar. The non-scrolled state keeps the inline
/// `CustomSegmentedControl` (underline style); these pills appear only once the header sticks.
struct ProfileStickyTabsHeader: View {
    @Environment(\.octopusTheme) private var theme

    let tabs: [LocalizedStringKey]
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(tabs.indices, id: \.self) { index in
                pill(index: index)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modify {
#if compiler(>=6.2)
            if #available(iOS 26.0, *) {
                // No opaque bar: the pills' own glass plus the translucent nav bar above give the
                // Instagram floating-glass look directly over the blurred content.
                $0.constrainedContentColumn(opaqueBackground: false)
            } else {
                $0.background(theme.colors.background)
                    .overlay(theme.colors.gray300.frame(height: 1), alignment: .bottom)
                    .constrainedContentColumn()
            }
#else
            $0.background(theme.colors.background)
                .overlay(theme.colors.gray300.frame(height: 1), alignment: .bottom)
                .constrainedContentColumn()
#endif
        }
    }

    @ViewBuilder
    private func pill(index: Int) -> some View {
        let isSelected = selectedTab == index
        Text(tabs[index], bundle: .module)
            .font(theme.fonts.body2.weight(.semibold))
            .foregroundColor(isSelected ? theme.colors.onPrimary : theme.colors.gray900)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Capsule())
            .modify {
#if compiler(>=6.2)
                if #available(iOS 26.0, *) {
                    if isSelected {
                        $0.glassEffect(.regular.tint(theme.colors.primary), in: Capsule())
                    } else {
                        $0.glassEffect(.regular, in: Capsule())
                    }
                } else {
                    $0.background(Capsule().fill(isSelected ? theme.colors.primary : theme.colors.gray200))
                }
#else
                $0.background(Capsule().fill(isSelected ? theme.colors.primary : theme.colors.gray200))
#endif
            }
            .onTapGesture {
                withAnimation(.spring(duration: 0.2)) { selectedTab = index }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityValueInBundle(
                isSelected ? "Accessibility.Common.Selected" : "Accessibility.Common.NotSelected")
    }
}
