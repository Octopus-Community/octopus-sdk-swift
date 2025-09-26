//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusCore

@available(iOS 16.0, *)
struct RootFeedPicker: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.presentationMode) private var presentationMode

    let rootFeeds: [RootFeed]
    @Binding var selectedRootFeed: RootFeed?

    @State private var contentHeight: CGFloat = .zero

    var body: some View {
        VStack { // Ensures the content wraps its natural height
            ContentView(rootFeeds: rootFeeds, selectedRootFeed: $selectedRootFeed)
                .readHeight($contentHeight)
                .opacity(contentHeight <= UIScreen.main.bounds.height * 0.8 ? 1 : 0) // Hide if scrolling is needed
        }
        .frame(height: min(contentHeight, UIScreen.main.bounds.height * 0.8)) // Limit height
        .overlay(
            ScrollingContentView(rootFeeds: rootFeeds, selectedRootFeed: $selectedRootFeed)
                .opacity(contentHeight > UIScreen.main.bounds.height * 0.8 ? 1 : 0) // Enable scrolling only if needed
        )
    }
}

@available(iOS 16.0, *)
private struct ContentView: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.presentationMode) private var presentationMode

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

@available(iOS 16.0, *)
private struct ScrollingContentView: View {
    @Environment(\.presentationMode) private var presentationMode

    let rootFeeds: [RootFeed]
    @Binding var selectedRootFeed: RootFeed?

    var body: some View {
        VStack(spacing: 10) {
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
    }
}

@available(iOS 16.0, *)
private struct RootFeedsGridView: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.presentationMode) private var presentationMode

    let rootFeeds: [RootFeed]
    @Binding var selectedRootFeed: RootFeed?

    var body: some View {
        FreeGridLayout {
            ForEach(rootFeeds, id: \.self) { rootFeed in
                Button(action: {
                    selectedRootFeed = rootFeed
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text(rootFeed.label)
                }
                .buttonStyle(OctopusBadgeButtonStyle(.medium, status: selectedRootFeed == rootFeed ? .on : .off))
                .padding(4)
            }
        }
        .padding(.horizontal)
    }
}
