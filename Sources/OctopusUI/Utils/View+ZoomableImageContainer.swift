//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import SwiftUI

struct ZoomableImageContainer<LeadingBarItem: View, CenteredBarItem: View, TrailingBarItem: View, PreTrailingView: View>: ViewModifier {
    @Environment(\.octopusTheme) private var theme

    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let defaultLeadingBarItem: LeadingBarItem
    let defaultTrailingBarItem: TrailingBarItem
    let defaultPreTrailingBarItem: PreTrailingView
    let defaultTrailingSharedBackgroundVisibility: Compat.Visibility
    let defaultCenteredBarItem: CenteredBarItem
    let defaultCenteredBarItemVisibility: Compat.Visibility
    let navBarTitle: Text
    let defaultNavigationBarBackButtonHidden: Bool
    let defaultNavigationBarPrimaryColor: Bool

    @State private var usableZoomableImageInfo: ZoomableImageInfo?
    private let zoomAnimationDuration = 0.2

    func body(content: Content) -> some View {
        ZStack {
            content

            if let usableZoomableImageInfo = usableZoomableImageInfo {
                PeekToViewContainer(
                    item: $zoomableImageInfo) {
                        ZoomableImageView(
                            image: zoomableImageInfo != nil ? usableZoomableImageInfo.image : usableZoomableImageInfo.transitionImage ?? usableZoomableImageInfo.image,
                            identifier: usableZoomableImageInfo.url,
                            isDisplayed: zoomableImageInfo != nil)
                    }
                    .transition(.identity)
                    .accessibilitySortPriority(10)
                    .accessibilityAddTraits(.isModal)
            }
        }
        .namespaced()
        .forceColorScheme(.dark, condition: zoomableImageInfo != nil)
        .onValueChanged(of: zoomableImageInfo) { zoomableImageInfo in
            guard let zoomableImageInfo else {
                // dispatch to the end of the animation the fact that the view is removed from the tree
                DispatchQueue.main.asyncAfter(deadline: .now() + zoomAnimationDuration) {
                    withAnimation(.spring(duration: 0.01)) {
                        usableZoomableImageInfo = nil
                    }
                }
                return
            }
            withAnimation(.spring(duration: zoomAnimationDuration)) {
                // display the view with the transition image
                usableZoomableImageInfo = ZoomableImageInfo(
                    url: zoomableImageInfo.url,
                    image: zoomableImageInfo.transitionImage ?? zoomableImageInfo.image)
                if zoomableImageInfo.transitionImage != nil {
                    // dispatch the display the full size image
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        withAnimation(.spring(duration: zoomAnimationDuration)) {
                            usableZoomableImageInfo = zoomableImageInfo
                        }
                    }
                }
            }
        }
        .toolbar(
            leading: leadingBarItem,
            preTrailing: preTrailingBarItem,
            trailing: trailingBarItem,
            centered: centeredBarItem,
            leadingSharedBackgroundVisibility: .hidden,
            preTrailingSharedBackgroundVisibility: .automatic,
            trailingSharedBackgroundVisibility: usableZoomableImageInfo != nil ? .hidden : defaultTrailingSharedBackgroundVisibility,
            centeredVisibility: usableZoomableImageInfo != nil ? .hidden : defaultCenteredBarItemVisibility)
        .navigationBarTitle(navBarTitle)
        .navigationBarBackButtonHidden(defaultNavigationBarBackButtonHidden || usableZoomableImageInfo != nil)
        .modify {
#if compiler(>=6.2)
            if #available(iOS 26.0, *), !defaultNavigationBarPrimaryColor {
                $0
                    .toolbarBackground(.hidden, for: .navigationBar)
            } else if #available(iOS 16.0, *), defaultNavigationBarPrimaryColor {
                $0
                    .toolbarBackground(theme.colors.primary, for: .navigationBar)
                    .toolbarBackground(zoomableImageInfo == nil ? .visible : .hidden, for: .navigationBar)
            } else {
                $0
            }
#else
            if #available(iOS 16.0, *), defaultNavigationBarPrimaryColor {
                $0
                    .toolbarBackground(theme.colors.primary, for: .navigationBar)
                    .toolbarBackground(zoomableImageInfo == nil ? .visible : .hidden, for: .navigationBar)
            } else {
                $0
            }
#endif
        }
    }

    @ViewBuilder
    private var leadingBarItem: some View {
        if usableZoomableImageInfo != nil {
            Spacer()
        } else {
            defaultLeadingBarItem
        }
    }

    @ViewBuilder
    private var preTrailingBarItem: some View {
        if usableZoomableImageInfo == nil {
            defaultPreTrailingBarItem
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var trailingBarItem: some View {
        if zoomableImageInfo != nil {
            Button(action: {
                withAnimation(.spring(duration: zoomAnimationDuration)) {
                    zoomableImageInfo = nil
                }
            }) {
                IconImage(theme.assets.icons.common.close)
                    .font(theme.fonts.navBarItem)
                    .modify {
#if compiler(>=6.2)
                        if #available(iOS 26.0, *) {
                            $0
                        } else {
                            $0.padding(.leading)
                        }
#else
                        $0.padding(.leading)
#endif
                    }
                    .foregroundColor(theme.colors.gray900)
                    .colorScheme(.dark)
                    .accessibilityLabelInBundle("Common.Close")
            }
        } else {
            defaultTrailingBarItem
        }
    }

    @ViewBuilder
    private var centeredBarItem: some View {
        if usableZoomableImageInfo != nil {
            EmptyView()
        } else {
            defaultCenteredBarItem
        }
    }
}

extension View {
    /// Create a zoomable image container
    /// This function has a textual center item (called title)
    func zoomableImageContainer<LeadingBarItem: View, TrailingBarItem: View, PreTrailingBarItem: View>(
        zoomableImageInfo: Binding<ZoomableImageInfo?>,
        defaultLeadingBarItem: LeadingBarItem,
        defaultPreTrailingBarItem: PreTrailingBarItem = EmptyView(),
        defaultTrailingBarItem: TrailingBarItem,
        defaultTrailingSharedBackgroundVisibility: Compat.Visibility = .automatic,
        defaultNavigationBarTitle: Text = Text(verbatim: ""),
        defaultNavigationBarTitleVisibility: Compat.Visibility = .automatic,
        defaultNavigationBarBackButtonHidden: Bool = false,
        defaultNavigationBarPrimaryColor: Bool = false) -> some View {
        self.modifier(
            ZoomableImageContainer(
                zoomableImageInfo: zoomableImageInfo,
                defaultLeadingBarItem: defaultLeadingBarItem,
                defaultTrailingBarItem: defaultTrailingBarItem,
                defaultPreTrailingBarItem: defaultPreTrailingBarItem,
                defaultTrailingSharedBackgroundVisibility: defaultTrailingSharedBackgroundVisibility,
                defaultCenteredBarItem: defaultNavigationBarTitle,
                defaultCenteredBarItemVisibility: defaultNavigationBarTitleVisibility,
                navBarTitle: defaultNavigationBarTitle,
                defaultNavigationBarBackButtonHidden: defaultNavigationBarBackButtonHidden,
                defaultNavigationBarPrimaryColor: defaultNavigationBarPrimaryColor
            )
        )
    }

    /// Create a zoomable image container
    /// This function has a center item as a view and takes a navBarTitle to build the back stack names
    func zoomableImageContainer<LeadingBarItem: View, CenteredBarItem: View, TrailingBarItem: View, PreTrailingBarItem: View>(
        zoomableImageInfo: Binding<ZoomableImageInfo?>,
        defaultLeadingBarItem: LeadingBarItem,
        defaultPreTrailingBarItem: PreTrailingBarItem = EmptyView(),
        defaultTrailingBarItem: TrailingBarItem,
        defaultTrailingSharedBackgroundVisibility: Compat.Visibility = .automatic,
        defaultCenteredBarItem: CenteredBarItem = EmptyView(),
        defaultCenteredBarItemVisibility: Compat.Visibility = .automatic,
        navBarTitle: Text = Text(verbatim: ""),
        defaultNavigationBarBackButtonHidden: Bool = false,
        defaultNavigationBarPrimaryColor: Bool = false) -> some View {
        self.modifier(
            ZoomableImageContainer(
                zoomableImageInfo: zoomableImageInfo,
                defaultLeadingBarItem: defaultLeadingBarItem,
                defaultTrailingBarItem: defaultTrailingBarItem,
                defaultPreTrailingBarItem: defaultPreTrailingBarItem,
                defaultTrailingSharedBackgroundVisibility: defaultTrailingSharedBackgroundVisibility,
                defaultCenteredBarItem: defaultCenteredBarItem,
                defaultCenteredBarItemVisibility: defaultCenteredBarItemVisibility,
                navBarTitle: navBarTitle,
                defaultNavigationBarBackButtonHidden: defaultNavigationBarBackButtonHidden,
                defaultNavigationBarPrimaryColor: defaultNavigationBarPrimaryColor
            )
        )
    }
}
