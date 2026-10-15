//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// The community screen a host container opens on: the feed, or the post a deep link names.
enum CommunityEntry {
    static func initialScreen(postId: String?) -> OctopusInitialScreen {
        guard let postId = postId?.trimmingCharacters(in: .whitespacesAndNewlines), !postId.isEmpty else {
            return .mainFeed
        }
        return .post(.init(postId: postId))
    }
}

/// The community in a host-owned full-screen modal: it opens directly on the community, whose root screen leads
/// with the host's Close (X).
struct CommunityModalContainer: View {
    var postId: String?

    @StateObjectCompat private var viewModel = SampleSDKViewModel()
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        OctopusUIView(
            octopus: viewModel.octopus,
            initialScreen: CommunityEntry.initialScreen(postId: postId),
            navigationMode: .navigationStack,
            navBarLeadingAction: .close(onTap: { presentationMode.wrappedValue.dismiss() }))
            .sampleCommunityTheme()
            .connectionErrorAlert()
            .accessibilityId("community-modal")
    }
}

/// The community in a bottom sheet: a drag handle on top, swiped down to come back.
struct CommunitySheetContainer: View {
    var postId: String?

    @StateObjectCompat private var viewModel = SampleSDKViewModel()

    var body: some View {
        OctopusUIView(
            octopus: viewModel.octopus,
            initialScreen: CommunityEntry.initialScreen(postId: postId),
            navigationMode: .navigationStack)
            .sampleCommunityTheme()
            .connectionErrorAlert()
            .accessibilityId("community-sheet")
            .modify {
                if #available(iOS 16.0, *) {
                    $0.presentationDragIndicator(.visible)
                } else { $0 }
            }
    }
}

/// A full-screen route opened from a Scenarios screen.
struct CommunityRoute: Hashable {
    var postId: String?
    /// Whether a host bottom bar sits under the community, which must then clear it.
    var showsHostBottomBar = false
}

/// The community full screen, above the tab bar, whose root screen leads with the host's Back.
///
/// It is a full-screen cover rather than a push: the community's `NavigationStack` nested in the Scenarios one
/// loses its navigation bar, and with it the Back.
struct CommunityFullScreenRoute: View {
    let route: CommunityRoute
    let onBack: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            OctopusUIView(
                octopus: OctopusSDKProvider.instance.octopus,
                bottomSafeAreaInset: route.showsHostBottomBar ? HostBottomBar.height : 0,
                initialScreen: CommunityEntry.initialScreen(postId: route.postId),
                navigationMode: .navigationStack,
                navBarLeadingAction: .back(onTap: onBack))
                .sampleCommunityTheme()
                .connectionErrorAlert()
                .ignoresSafeArea(edges: route.showsHostBottomBar ? .bottom : [])
            if route.showsHostBottomBar {
                HostBottomBar()
            }
        }
        .accessibilityId("community-fullscreen")
    }
}

/// A stand-in for a host app's own bottom bar, under the full-screen community (Full screen preset 3).
private struct HostBottomBar: View {
    static let height: CGFloat = 56

    var body: some View {
        HStack {
            ForEach(["house", "magnifyingglass", "person"], id: \.self) { symbol in
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundColor(SampleTokens.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            }
        }
        .frame(height: Self.height)
        .frame(maxWidth: .infinity)
        .background(
            SampleTokens.Colors.surface
                .overlay(Rectangle().fill(SampleTokens.Colors.hairline).frame(height: 1), alignment: .top)
                .ignoresSafeArea(edges: .bottom))
        .accessibilityElement(children: .ignore)
        .accessibilityLabelCompat("Host app bottom bar")
        .accessibilityId("fullscreen-host-bottom-bar")
    }
}

extension View {
    /// Shows the community full screen while `route` is set.
    func communityRoute(_ route: Binding<CommunityRoute?>) -> some View {
        modifier(CommunityRouteModifier(route: route))
    }
}

private struct CommunityRouteModifier: ViewModifier {
    @Binding var route: CommunityRoute?

    private var isPresented: Binding<Bool> {
        Binding(get: { route != nil }, set: { if !$0 { route = nil } })
    }

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: isPresented) {
                if let route {
                    CommunityFullScreenRoute(route: route, onBack: { self.route = nil })
                }
            }
            // A tapped push is routed by the shell to the Community tab: the full-screen route closes instead.
            .dismissedOnPushRouting($route)
    }
}

/// Opens the community in one of the containers a host gives it. Full screen is owned by the screen that holds
/// the route (`communityRoute(_:)`).
@MainActor
struct CommunityPresenter {
    let showFullScreen: (@escaping () -> any View) -> Void
    let showInSheet: (@escaping () -> any View) -> Void

    func openTab() {
        SampleTabRouter.instance.select(.community)
    }

    func openModal(postId: String? = nil) {
        showFullScreen { CommunityModalContainer(postId: postId) }
    }

    func openSheet(postId: String? = nil) {
        showInSheet { CommunitySheetContainer(postId: postId) }
    }
}
