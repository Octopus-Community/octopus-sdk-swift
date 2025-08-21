//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI


@available(iOS 16.0, *)
struct TopicPicker: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.presentationMode) private var presentationMode

    let topics: [CreatePostViewModel.DisplayableTopic]
    @Binding var selectedTopic: CreatePostViewModel.DisplayableTopic?

    @State private var contentHeight: CGFloat = .zero

    var body: some View {
        VStack { // Ensures the content wraps its natural height
            ContentView(topics: topics, selectedTopic: $selectedTopic)
                .readHeight($contentHeight)
                .opacity(contentHeight <= UIScreen.main.bounds.height * 0.8 ? 1 : 0) // Hide if scrolling is needed
        }
        .frame(height: min(contentHeight, UIScreen.main.bounds.height * 0.8)) // Limit height
        .overlay(
            ScrollingContentView(topics: topics, selectedTopic: $selectedTopic)
                .opacity(contentHeight > UIScreen.main.bounds.height * 0.8 ? 1 : 0) // Enable scrolling only if needed
        )
    }
}

@available(iOS 16.0, *)
private struct ContentView: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.presentationMode) private var presentationMode

    let topics: [CreatePostViewModel.DisplayableTopic]
    @Binding var selectedTopic: CreatePostViewModel.DisplayableTopic?

    var body: some View {
        VStack(spacing: 10) {
            TitleView()
            TopicsGridView(topics: topics, selectedTopic: $selectedTopic)
        }
        .padding(.top, 10)
    }
}

@available(iOS 16.0, *)
private struct ScrollingContentView: View {
    @Environment(\.presentationMode) private var presentationMode

    let topics: [CreatePostViewModel.DisplayableTopic]
    @Binding var selectedTopic: CreatePostViewModel.DisplayableTopic?

    var body: some View {
        VStack(spacing: 10) {
            TitleView()
            ScrollView {
                TopicsGridView(topics: topics, selectedTopic: $selectedTopic)
            }
        }
        .padding(.top, 10)
    }
}

private struct TitleView: View {
    @Environment(\.octopusTheme) private var theme

    var body: some View {
        Text("Post.Create.Topic.Selection.Title", bundle: .module)
            .font(theme.fonts.body2)
            .fontWeight(.semibold)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding()
    }
}

@available(iOS 16.0, *)
private struct TopicsGridView: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.presentationMode) private var presentationMode

    let topics: [CreatePostViewModel.DisplayableTopic]
    @Binding var selectedTopic: CreatePostViewModel.DisplayableTopic?

    var body: some View {
        CenteredFreeGridLayout {
            ForEach(topics, id: \.self) { topic in
                Button(action: {
                    selectedTopic = topic
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text(topic.name)
                }
                .buttonStyle(OctopusBadgeButtonStyle(.medium, status: selectedTopic == topic ? .on : .off))
                .padding(4)
            }
        }
        .padding(.horizontal)
    }
}

@available(iOS 16.0, *)
#Preview {
    TopicPicker(
        topics: [
            .init(topicId: "1", name: "Sports"),
            .init(topicId: "2", name: "Cooking"),
            .init(topicId: "3", name: "Travel"),
        ],
        selectedTopic: .constant(nil))
}
