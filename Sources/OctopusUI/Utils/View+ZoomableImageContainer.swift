//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import SwiftUI

struct ZoomableImageContainer<LeadingBarItem: View, TrailingBarItem: View>: ViewModifier {
    @Environment(\.octopusTheme) private var theme

    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let defaultLeadingBarItem: LeadingBarItem
    let defaultTrailingBarItem: TrailingBarItem
    let defaultNavigationBarTitle: Text
    let defaultNavigationBarBackButtonHidden: Bool

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
        .navigationBarItems(leading: leadingBarItem, trailing: trailingBarItem)
        .navigationBarTitle(
            usableZoomableImageInfo == nil ? defaultNavigationBarTitle : Text(verbatim: ""),
            displayMode: .inline)
        .navigationBarBackButtonHidden(defaultNavigationBarBackButtonHidden || usableZoomableImageInfo != nil)
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
    private var trailingBarItem: some View {
        if zoomableImageInfo != nil {
            Button(action: {
                withAnimation(.spring(duration: zoomAnimationDuration)) {
                    zoomableImageInfo = nil
                }
            }) {
                Image(systemName: "xmark")
                    .font(theme.fonts.navBarItem.weight(.semibold))
                    .padding(.leading)
                    .foregroundColor(theme.colors.primary)
                    .colorScheme(.dark)
            }
        } else {
            defaultTrailingBarItem
        }
    }
}

extension View {
    func zoomableImageContainer<LeadingBarItem: View, TrailingBarItem: View>(
        zoomableImageInfo: Binding<ZoomableImageInfo?>,
        defaultLeadingBarItem: LeadingBarItem,
        defaultTrailingBarItem: TrailingBarItem,
        defaultNavigationBarTitle: Text = Text(verbatim: ""),
        defaultNavigationBarBackButtonHidden: Bool = false) -> some View {
        self.modifier(
            ZoomableImageContainer(
                zoomableImageInfo: zoomableImageInfo,
                defaultLeadingBarItem: defaultLeadingBarItem,
                defaultTrailingBarItem: defaultTrailingBarItem,
                defaultNavigationBarTitle: defaultNavigationBarTitle,
                defaultNavigationBarBackButtonHidden: defaultNavigationBarBackButtonHidden
            )
        )
    }
}
