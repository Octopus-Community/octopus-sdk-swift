//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

struct RootFeedPicker: View {
    let rootFeeds: [RootFeed]
    @Binding var selectedRootFeed: RootFeed?

    @State private var contentHeight: CGFloat = .zero

    var body: some View {
        ContentSizedSheet(
            content: { ContentView(rootFeeds: rootFeeds, selectedRootFeed: $selectedRootFeed) },
            scrollingContent: { ScrollingContentView(rootFeeds: rootFeeds, selectedRootFeed: $selectedRootFeed) }
        )
    }
}

private struct ContentView: View {
    let rootFeeds: [RootFeed]
    @Binding var selectedRootFeed: RootFeed?

    var body: some View {
        VStack(spacing: 10) {
            TitleView()
            RootFeedsGridView(rootFeeds: rootFeeds, selectedRootFeed: $selectedRootFeed)
            PoweredByOctopusView()
        }
        .padding(.top, 10)
    }
}

private struct ScrollingContentView: View {
    @Environment(\.octopusTheme) private var theme

    let rootFeeds: [RootFeed]
    @Binding var selectedRootFeed: RootFeed?

    var body: some View {
        VStack(spacing: 10) {
            if #unavailable(iOS 16.0) {
                Capsule()
                    .fill(theme.colors.gray300)
                    .frame(width: 50, height: 8)
            }
            TitleView()
            ScrollView {
                RootFeedsGridView(rootFeeds: rootFeeds, selectedRootFeed: $selectedRootFeed)
            }
            PoweredByOctopusView()
        }
        .padding(.top, 10)
    }
}

private struct TitleView: View {
    @Environment(\.octopusTheme) private var theme

    var body: some View {
        Text("Feed.Filter", bundle: .module)
            .font(theme.fonts.body2)
            .fontWeight(.semibold)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding()
            .accessibilityAddTraits(.isHeader)
    }
}

private struct RootFeedsGridView: View {
    @Environment(\.octopusTheme) private var theme

    let rootFeeds: [RootFeed]
    @Binding var selectedRootFeed: RootFeed?

    var body: some View {
        if #available(iOS 16.0, *) {
            FreeGridLayout {
                RootFeedsListView(rootFeeds: rootFeeds, selectedRootFeed: $selectedRootFeed)
            }
            .padding(.horizontal)
        } else {
            VStack {
                RootFeedsListView(rootFeeds: rootFeeds, selectedRootFeed: $selectedRootFeed)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
        }
    }
}

private struct RootFeedsListView: View {
    @Environment(\.presentationMode) private var presentationMode

    let rootFeeds: [RootFeed]
    @Binding var selectedRootFeed: RootFeed?

    var body: some View {
        ForEach(rootFeeds, id: \.self) { rootFeed in
            Button(action: {
                selectedRootFeed = rootFeed
                presentationMode.wrappedValue.dismiss()
            }) {
                Text(rootFeed.label)
            }
            .buttonStyle(OctopusBadgeButtonStyle(.medium, status: selectedRootFeed == rootFeed ? .on : .off))
            .padding(4)
            .accessibilityValueInBundle(selectedRootFeed == rootFeed ? "Accessibility.Common.Selected" : "Accessibility.Common.NotSelected")
        }
    }
}
