//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

struct RootFeedsView: View {
    @Compat.StateObject private var viewModel: RootFeedsViewModel

    @State private var showRootFeedPicker = false
    @State private var rootFeedPickerDetentHeight: CGFloat = 0

    @State private var displayError = false
    @State private var displayableError: DisplayableString?

    init(octopus: OctopusSDK) {
        _viewModel = Compat.StateObject(wrappedValue: RootFeedsViewModel(octopus: octopus))
    }

    var body: some View {
        VStack(spacing: 0) {
            ContentView(rootFeeds: viewModel.rootFeeds, selectedRootFeed: $viewModel.selectedRootFeed,
                        showRootFeedPicker: $showRootFeedPicker)
            PostListView(octopus: viewModel.octopus, selectedRootFeed: $viewModel.selectedRootFeed)
        }
        .sheet(isPresented: $showRootFeedPicker) {
            if #available(iOS 16.0, *) {
                RootFeedPicker(rootFeeds: viewModel.rootFeeds, selectedRootFeed: $viewModel.selectedRootFeed)
                .readHeight()
                .onPreferenceChange(HeightPreferenceKey.self) { [$rootFeedPickerDetentHeight] height in
                    if let height {
                        // add a small padding otherwise multi line texts are not correctly rendered
                        // TODO: change that fixed size to a ScaledMetric (but not available on iOS 13)
                        $rootFeedPickerDetentHeight.wrappedValue = height + 40
                    }
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
        .alert(
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
                    Image(.search)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .padding(.leading, 16)
                }
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
                .font(theme.fonts.body2)
                .fontWeight(.medium)
                .foregroundColor(
                    selectedRootFeed == rootFeed ?
                        theme.colors.textOnAccent :
                        theme.colors.accent
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .foregroundColor(
                            selectedRootFeed == rootFeed ?
                                theme.colors.accent :
                                theme.colors.accent.opacity(0.1)
                        )
                )
        }
    }
}
