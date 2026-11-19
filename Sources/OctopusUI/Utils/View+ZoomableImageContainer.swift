//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import SwiftUI

struct ZoomableImageContainer<LeadingBarItem: View, CenteredBarItem: View, TrailingBarItem: View, PreTrailingView: View>: ViewModifier {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.sharedEnvironmentObjects) private var sharedEnvironmentObjects

    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let defaultLeadingBarItem: LeadingBarItem
    let defaultLeadingSharedBackgroundVisibility: Compat.Visibility
    let defaultTrailingBarItem: TrailingBarItem
    let defaultPreTrailingBarItem: PreTrailingView
    let defaultTrailingSharedBackgroundVisibility: Compat.Visibility
    let defaultPreTrailingSharedBackgroundVisibility: Compat.Visibility
    let defaultCenteredBarItem: CenteredBarItem
    let defaultCenteredBarItemVisibility: Compat.Visibility
    let navBarTitle: Text
    let defaultNavigationBarBackButtonHidden: Bool
    let defaultNavigationBarPrimaryColor: Bool
    /// Suppresses the iOS 26 transparent (`.hidden`) nav bar background so an opaque
    /// `UINavigationBarAppearance` (see `opaqueNavigationBar`) can take over. Used by screens
    /// whose content scrolls under the bar and must stay legible.
    let defaultNavigationBarOpaque: Bool
    /// Forces the system navigation title to `.inline` independently of `defaultNavigationBarOpaque`.
    /// Needed by a navigation *root* (e.g. the main feed) that wants a translucent/glass bar but must
    /// avoid the default `.automatic` large-title block.
    let forceInlineTitle: Bool

    func body(content: Content) -> some View {
        content
            // The viewer is presented by UIKit, over the whole screen: the navigation bar stays as it is.
            .fullscreenImageViewer(
                $zoomableImageInfo, theme: theme,
                locale: sharedEnvironmentObjects?.languageManager.overridenLocale)
            .modify {
                // The background the navigation bar has always had on these screens.
                if #available(iOS 16.0, *) {
                    $0.toolbarBackground(theme.colors.background, for: .navigationBar)
                } else { $0 }
            }
            .toolbar(
                leading: defaultLeadingBarItem,
                preTrailing: defaultPreTrailingBarItem,
                trailing: defaultTrailingBarItem,
                centered: defaultCenteredBarItem,
                leadingSharedBackgroundVisibility: defaultLeadingSharedBackgroundVisibility,
                preTrailingSharedBackgroundVisibility: defaultPreTrailingSharedBackgroundVisibility,
                trailingSharedBackgroundVisibility: defaultTrailingSharedBackgroundVisibility,
                centeredVisibility: defaultCenteredBarItemVisibility)
            // Opaque bars force `.inline`: otherwise the (default `.automatic`) large title at a
            // navigation root renders as a tall opaque block. The visible title is a principal item.
            .navigationBarTitle(navBarTitle,
                                displayMode: (defaultNavigationBarOpaque || forceInlineTitle) ? .inline : .automatic)
            .navigationBarBackButtonHidden(defaultNavigationBarBackButtonHidden)
            .modify {
#if compiler(>=6.2)
                if #available(iOS 16.0, *), defaultNavigationBarOpaque {
                    // Opacity is enforced by an opaque `UINavigationBarAppearance` (see
                    // `opaqueNavigationBar`); don't let SwiftUI hide the bar on iOS 26. Locking the
                    // bar's color scheme stops the iOS 26 content-adaptive vibrancy from flipping the
                    // title/buttons to white over dark (e.g. video) content scrolling underneath.
                    $0.toolbarColorScheme(colorScheme, for: .navigationBar)
                } else if defaultNavigationBarOpaque {
                    $0
                } else if #available(iOS 26.0, *), GlassEffect.isAvailable, !defaultNavigationBarPrimaryColor {
                    $0
                        .toolbarBackground(.hidden, for: .navigationBar)
                } else if #available(iOS 16.0, *), defaultNavigationBarPrimaryColor {
                    $0
                        .toolbarBackground(theme.colors.primary, for: .navigationBar)
                        .toolbarBackground(.visible, for: .navigationBar)
                } else {
                    $0
                }
#else
                if #available(iOS 16.0, *), defaultNavigationBarPrimaryColor {
                    $0
                        .toolbarBackground(theme.colors.primary, for: .navigationBar)
                        .toolbarBackground(.visible, for: .navigationBar)
                } else {
                    $0
                }
#endif
            }
    }
}

extension View {
    /// Create a zoomable image container
    /// This function has a textual center item (called title)
    func zoomableImageContainer<LeadingBarItem: View, TrailingBarItem: View, PreTrailingBarItem: View>(
        zoomableImageInfo: Binding<ZoomableImageInfo?>,
        defaultLeadingBarItem: LeadingBarItem = EmptyView(),
        defaultLeadingSharedBackgroundVisibility: Compat.Visibility = .automatic,
        defaultPreTrailingBarItem: PreTrailingBarItem = EmptyView(),
        defaultPreTrailingSharedBackgroundVisibility: Compat.Visibility = .automatic,
        defaultTrailingBarItem: TrailingBarItem,
        defaultTrailingSharedBackgroundVisibility: Compat.Visibility = .automatic,
        defaultNavigationBarTitle: Text = Text(verbatim: ""),
        defaultNavigationBarTitleVisibility: Compat.Visibility = .automatic,
        defaultNavigationBarBackButtonHidden: Bool = false,
        defaultNavigationBarPrimaryColor: Bool = false,
        defaultNavigationBarOpaque: Bool = false,
        forceInlineTitle: Bool = false) -> some View {
        self.modifier(
            ZoomableImageContainer(
                zoomableImageInfo: zoomableImageInfo,
                defaultLeadingBarItem: defaultLeadingBarItem,
                defaultLeadingSharedBackgroundVisibility: defaultLeadingSharedBackgroundVisibility,
                defaultTrailingBarItem: defaultTrailingBarItem,
                defaultPreTrailingBarItem: defaultPreTrailingBarItem,
                defaultTrailingSharedBackgroundVisibility: defaultTrailingSharedBackgroundVisibility,
                defaultPreTrailingSharedBackgroundVisibility: defaultPreTrailingSharedBackgroundVisibility,
                // A `Text` rendered inside `ToolbarItem(placement: .principal)`
                // does not inherit the system navigation title styling the way
                // `.navigationBarTitle(_:displayMode: .inline)` does, so we
                // explicitly apply the inline nav title font. The helper reads
                // the font from `UINavigationBar.appearance()` so any host-app
                // customization is honored, and falls back to the system
                // default (`.headline`) otherwise — keeping this path visually
                // consistent with screens that render their title through
                // `.navigationBarTitle`.
                defaultCenteredBarItem: defaultNavigationBarTitle.inlineNavigationBarTitleFont(),
                defaultCenteredBarItemVisibility: defaultNavigationBarTitleVisibility,
                navBarTitle: defaultNavigationBarTitle,
                defaultNavigationBarBackButtonHidden: defaultNavigationBarBackButtonHidden,
                defaultNavigationBarPrimaryColor: defaultNavigationBarPrimaryColor,
                defaultNavigationBarOpaque: defaultNavigationBarOpaque,
                forceInlineTitle: forceInlineTitle
            )
        )
    }

    /// Create a zoomable image container
    /// This function has a center item as a view and takes a navBarTitle to build the back stack names
    func zoomableImageContainer<LeadingBarItem: View, CenteredBarItem: View, TrailingBarItem: View, PreTrailingBarItem: View>(
        zoomableImageInfo: Binding<ZoomableImageInfo?>,
        defaultLeadingBarItem: LeadingBarItem = EmptyView(),
        defaultLeadingSharedBackgroundVisibility: Compat.Visibility = .automatic,
        defaultPreTrailingBarItem: PreTrailingBarItem = EmptyView(),
        defaultPreTrailingSharedBackgroundVisibility: Compat.Visibility = .automatic,
        defaultTrailingBarItem: TrailingBarItem,
        defaultTrailingSharedBackgroundVisibility: Compat.Visibility = .automatic,
        defaultCenteredBarItem: CenteredBarItem = EmptyView(),
        defaultCenteredBarItemVisibility: Compat.Visibility = .automatic,
        navBarTitle: Text = Text(verbatim: ""),
        defaultNavigationBarBackButtonHidden: Bool = false,
        defaultNavigationBarPrimaryColor: Bool = false,
        defaultNavigationBarOpaque: Bool = false,
        forceInlineTitle: Bool = false) -> some View {
        self.modifier(
            ZoomableImageContainer(
                zoomableImageInfo: zoomableImageInfo,
                defaultLeadingBarItem: defaultLeadingBarItem,
                defaultLeadingSharedBackgroundVisibility: defaultLeadingSharedBackgroundVisibility,
                defaultTrailingBarItem: defaultTrailingBarItem,
                defaultPreTrailingBarItem: defaultPreTrailingBarItem,
                defaultTrailingSharedBackgroundVisibility: defaultTrailingSharedBackgroundVisibility,
                defaultPreTrailingSharedBackgroundVisibility: defaultPreTrailingSharedBackgroundVisibility,
                defaultCenteredBarItem: defaultCenteredBarItem,
                defaultCenteredBarItemVisibility: defaultCenteredBarItemVisibility,
                navBarTitle: navBarTitle,
                defaultNavigationBarBackButtonHidden: defaultNavigationBarBackButtonHidden,
                defaultNavigationBarPrimaryColor: defaultNavigationBarPrimaryColor,
                defaultNavigationBarOpaque: defaultNavigationBarOpaque,
                forceInlineTitle: forceInlineTitle
            )
        )
    }
}
