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
        VStack {
            TitleView()
            RootFeedsGridView(rootFeeds: rootFeeds, selectedRootFeed: $selectedRootFeed)
        }
        .padding(.bottom)
    }
}

@available(iOS 16.0, *)
private struct ScrollingContentView: View {
    @Environment(\.presentationMode) private var presentationMode

    let rootFeeds: [RootFeed]
    @Binding var selectedRootFeed: RootFeed?

    var body: some View {
        VStack {
            TitleView()
            ScrollView {
                RootFeedsGridView(rootFeeds: rootFeeds, selectedRootFeed: $selectedRootFeed)
            }
        }
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
        CenteredFreeGridLayout {
            ForEach(rootFeeds, id: \.self) { rootFeed in
                Button(action: {
                    selectedRootFeed = rootFeed
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text(rootFeed.label)
                        .font(theme.fonts.body2)
                        .fontWeight(.medium)
                        .foregroundColor(
                            selectedRootFeed == rootFeed ?
                            theme.colors.onPrimary :
                                theme.colors.primary
                        )
                        .padding(10)
                        .background(
                            Capsule()
                                .foregroundColor(
                                    selectedRootFeed == rootFeed ?
                                    theme.colors.primary :
                                        theme.colors.primaryLowContrast
                                )
                        )
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }
}
