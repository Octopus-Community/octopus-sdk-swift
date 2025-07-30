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
    @Compat.StateObject private var viewModel: RootFeedsViewModel

    @State private var showRootFeedPicker = false
    @State private var rootFeedPickerDetentHeight: CGFloat = 0

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
        VStack(spacing: 0) {
            ContentView(rootFeeds: viewModel.rootFeeds, selectedRootFeed: $viewModel.selectedRootFeed,
                        showRootFeedPicker: $showRootFeedPicker)
            PostListView(octopus: viewModel.octopus, mainFlowPath: mainFlowPath,
                         selectedRootFeed: $viewModel.selectedRootFeed,
                         zoomableImageInfo: $zoomableImageInfo)
        }
        .zoomableImageContainer(zoomableImageInfo: $zoomableImageInfo,
                                defaultLeadingBarItem: leadingBarItem,
                                defaultTrailingBarItem: trailingBarItem,
                                defaultNavigationBarPrimaryColor: navBarPrimaryColor)
        .sheet(isPresented: $showRootFeedPicker) {
            if #available(iOS 16.0, *) {
                RootFeedPicker(rootFeeds: viewModel.rootFeeds, selectedRootFeed: $viewModel.selectedRootFeed)
                .readHeight($height)
                .onValueChanged(of: height) { [$rootFeedPickerDetentHeight] height in
                    // add a small padding otherwise multi line texts are not correctly rendered
                    // TODO: change that fixed size to a ScaledMetric (but not available on iOS 13)
                    $rootFeedPickerDetentHeight.wrappedValue = height + 40
                }
                .presentationDetents([.height(rootFeedPickerDetentHeight)])
                .presentationDragIndicator(.visible)
                .modify {
                    if #available(iOS 16.4, *) {
                        $0.presentationContentInteraction(.scrolls)
                    } else {
                        $0
                    }
                }

            } else {
                Picker(L10n("Filter by topic"), selection: $viewModel.selectedRootFeed) {
                    ForEach(viewModel.rootFeeds, id: \.self) {
                        Text($0.label)
                            .tag($0)
                    }
                }.pickerStyle(.wheel)
            }
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
                .frame(height: 28)
        case let .text(title):
            Text(title.text)
                .font(theme.fonts.title2)
                .fontWeight(.semibold)
                .foregroundColor(navBarPrimaryColor ? theme.colors.onPrimary : theme.colors.gray900)
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
        }
    }
}

private struct ContentView: View {
    @Environment(\.octopusTheme) private var theme
    let rootFeeds: [RootFeed]
    @Binding var selectedRootFeed: RootFeed?
    @Binding var showRootFeedPicker: Bool

    @State var scrollToId: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { showRootFeedPicker = true }) {
                    Image(res: .search)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .padding(.leading, 16)
                        .foregroundColor(theme.colors.gray900)
                }
                .buttonStyle(.plain)
                Compat.ScrollView(.horizontal, scrollToId: $scrollToId) {
                    HStack(spacing: 8) {
                        ForEach(rootFeeds, id: \.feedId) { rootFeed in
                            RootFeedChip(rootFeed: rootFeed, selectedRootFeed: $selectedRootFeed)
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
    }
}
