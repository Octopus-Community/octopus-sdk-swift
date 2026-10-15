//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

/// The navigation container of one host-app tab: a `NavigationStack` where the OS has it, a stack-styled
/// `NavigationView` below iOS 16 (the sample still runs on iOS 15).
///
/// Only host-app tabs use it. The Community tab never does: `OctopusHomeScreen` owns its navigation, and
/// wrapping it in a second container would stack two navigation bars.
struct SampleNavigationContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack(root: content)
        } else {
            NavigationView(content: content)
                .navigationViewStyle(.stack)
        }
    }
}

/// The platform mark shown on the tab-root bars, mirroring Android's `platform-badge` (the DS
/// PlatformMarker): the Apple glyph and "iOS", so a screenshot always says which platform it was taken on.
///
/// It is an identity, never a control, exactly as on Android ("the marker never becomes a button"): plain
/// text in the leading bar slot, no capsule, no glass, no hit target, read by VoiceOver as static text.
struct PlatformBadge: View {
    var body: some View {
        HStack(spacing: SampleTokens.Spacing.space1) {
            // U+F8FF is the Apple logo in Apple's system fonts, which is all this mark is ever drawn with.
            Text(verbatim: "\u{F8FF}")
            Text(verbatim: "iOS")
        }
        .font(SampleTokens.Typography.badgeLabel)
        // Capped like the system bar items: past this size the bar slot truncates the mark to "i…".
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .fixedSize()
        .foregroundColor(SampleTokens.Colors.textSecondary)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabelCompat("iOS")
        .accessibilityAddTraits(.isStaticText)
        .accessibilityId("platform-badge")
    }
}

extension View {
    /// Styles a tab root: a large native title and the platform mark in the leading bar slot (free on a
    /// tab root, which has no back button). Pushed screens keep their own inline titles and no mark, as on
    /// Android.
    func sampleTabRoot(_ title: String) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
            .samplePlatformMark { PlatformBadge() }
    }
}
