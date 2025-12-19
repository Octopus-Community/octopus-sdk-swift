//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

struct RootFeedsView: View {
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.octopusTheme) private var theme
    @EnvironmentObject private var translationStore: ContentTranslationPreferenceStore

    @Compat.StateObject private var viewModel: RootFeedsViewModel

    @State private var showRootFeedPicker = false
    @State private var rootFeedPickerDetentHeight: CGFloat = 80

    @State private var displayError = false
    @State private var displayableError: DisplayableString?
    @State private var height: CGFloat = 0

    private let mainFlowPath: MainFlowPath
    private let navBarLeadingItem: OctopusHomeScreen.NavBarLeadingItemKind
    private let navBarPrimaryColor: Bool

    @State private var zoomableImageInfo: ZoomableImageInfo?

    init(octopus: OctopusSDK, mainFlowPath: MainFlowPath, navBarLeadingItem: OctopusHomeScreen.NavBarLeadingItemKind,
         navBarPrimaryColor: Bool) {
        _viewModel = Compat.StateObject(wrappedValue: RootFeedsViewModel(octopus: octopus))
        self.mainFlowPath = mainFlowPath
        self.navBarLeadingItem = navBarLeadingItem
        self.navBarPrimaryColor = navBarPrimaryColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if UIAccessibility.isVoiceOverRunning {
                Text("Accessibility.Header.RootFeeds", bundle: .module)
                    .font(theme.fonts.body1)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.colors.gray900)
                    .padding(.leading, 8)
                    .accessibilityAddTraits(.isHeader)
            }
            ContentView(rootFeeds: viewModel.rootFeeds, selectedRootFeed: $viewModel.selectedRootFeed,
                        showRootFeedPicker: $showRootFeedPicker)

            if UIAccessibility.isVoiceOverRunning {
                Text("Accessibility.Header.PostList", bundle: .module)
                    .font(theme.fonts.body1)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.colors.gray900)
                    .padding(.top, 16)
                    .padding(.leading, 8)
                    .accessibilityAddTraits(.isHeader)
            }
            PostListView(octopus: viewModel.octopus, mainFlowPath: mainFlowPath, translationStore: translationStore,
                         selectedRootFeed: $viewModel.selectedRootFeed,
                         zoomableImageInfo: $zoomableImageInfo)
        }
        .zoomableImageContainer(zoomableImageInfo: $zoomableImageInfo,
                                defaultLeadingBarItem: leadingBarItem,
                                defaultTrailingBarItem: trailingBarItem,
                                defaultNavigationBarPrimaryColor: navBarPrimaryColor)
        .sheet(isPresented: $showRootFeedPicker) {
            RootFeedPicker(rootFeeds: viewModel.rootFeeds, selectedRootFeed: $viewModel.selectedRootFeed)
                .sizedSheet()
        }
        .compatAlert(
            "Common.Error",
            isPresented: $displayError,
            presenting: displayableError,
            actions: { _ in },
            message: { error in
                error.textView
            })
        .onReceive(viewModel.$error) { error in
            guard let error else { return }
            displayableError = error
            displayError = true
        }
    }

    @ViewBuilder
    private var leadingBarItem: some View {
        switch navBarLeadingItem {
        case .logo:
            Image(uiImage: theme.assets.logo)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 33)
                .fixedSize()
                .accessibilityHidden(true)
        case let .text(title):
            Text(title.text)
                .font(theme.fonts.title2)
                .fontWeight(.semibold)
                .foregroundColor(navBarPrimaryColor ? theme.colors.onPrimary : theme.colors.gray900)
                .fixedSize()
        }
    }

    @ViewBuilder
    private var trailingBarItem: some View {
        if presentationMode.wrappedValue.isPresented {
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Common.Close", bundle: .module)
                    .font(theme.fonts.navBarItem)
                    .foregroundColor(navBarPrimaryColor ? theme.colors.onPrimary : theme.colors.primary)
            }
            .modify {
#if compiler(>=6.2)
                if #available(iOS 26.0, *), navBarPrimaryColor {
                    $0.glassEffect(.regular.tint(theme.colors.primary))
                } else {
                    $0
                }
#else
                $0
#endif
            }
        }
    }
}

private struct ContentView: View {
    @Environment(\.octopusTheme) private var theme
    let rootFeeds: [RootFeed]
    @Binding var selectedRootFeed: RootFeed?
    @Binding var showRootFeedPicker: Bool

    @State private var scrollToId: String?

    @State private var scrollViewHeight: CGFloat = 44

    var searchButtonSize: CGFloat {
        min(max(scrollViewHeight, 44), 88)
    }

    var body: some View {
        VStack(spacing: 0) {
#if compiler(>=6.2)
            // Disable nav bar opacity on iOS 26 to have the same behavior as before.
            // TODO: See with product team if we need to keep it.
            if #available(iOS 26.0, *) {
                Color.white.opacity(0.0001)
                    .frame(maxWidth: .infinity)
                    .frame(height: 1)
            }
#endif
            HStack {
                Button(action: { showRootFeedPicker = true }) {
                    HStack {
                        Image(res: .search)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(.leading, 12)
                            .foregroundColor(theme.colors.gray900)
                            .accessibilityLabelInBundle("Feed.Filter")
                    }.frame(width:searchButtonSize, height: searchButtonSize)
                }
                .buttonStyle(.plain)
                Compat.ScrollView(.horizontal, scrollToId: $scrollToId, idAnchor: .center, canScrollToExtremities: false) {
                    HStack(spacing: 8) {
                        ForEach(rootFeeds, id: \.feedId) { rootFeed in
                            RootFeedChip(rootFeed: rootFeed, selectedRootFeed: $selectedRootFeed)
                                .frame(minHeight: 44)
                        }
                    }
                    .padding(.trailing, 20)
                }
                .modify {
                    if #available(iOS 16.0, *) {
                        $0.scrollIndicators(.hidden)
                    } else { $0 }
                }
                .modify {
                    if #available(iOS 15.0, *) {
                        // fixed a weird bug where the horizontal scrollview of RootFeedsView view is refreshable
                        if let keyPath = \EnvironmentValues.refresh as? WritableKeyPath<EnvironmentValues, RefreshAction?> {
                            $0.environment(keyPath, nil)
                        }
                    } else {
                        $0
                    }
                }
                .readHeight($scrollViewHeight)
            }
        }
        .onValueChanged(of: selectedRootFeed) {
            guard let selectedRootFeed = $0 else { return }
            scrollToId = selectedRootFeed.feedId
        }
    }
}

private struct RootFeedChip: View {
    @Environment(\.octopusTheme) private var theme

    let rootFeed: RootFeed
    @Binding var selectedRootFeed: RootFeed?


    var body: some View {
        Button(action: {
            selectedRootFeed = rootFeed
        }) {
            Text(rootFeed.label)
        }
        .buttonStyle(OctopusBadgeButtonStyle(.medium, status: selectedRootFeed == rootFeed ? .on : .off))
        .accessibilityValueInBundle(selectedRootFeed == rootFeed ? "Accessibility.Common.Selected" : "Accessibility.Common.NotSelected")
    }
}
