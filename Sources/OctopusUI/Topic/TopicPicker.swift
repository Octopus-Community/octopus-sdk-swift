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

    var body: some View {
        VStack {
            Text("Post.Create.Topic.Selection.Title", bundle: .module)
                .multilineTextAlignment(.center)
                .font(theme.fonts.body2)
                .fontWeight(.semibold)
                .padding()
            CenteredFreeGridLayout {
                ForEach(topics, id: \.self) { topic in
                    Button(action: {
                        selectedTopic = topic
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text(topic.name)
                            .font(theme.fonts.body2)
                            .fontWeight(.medium)
                            .foregroundColor(
                                selectedTopic == topic ?
                                    theme.colors.onPrimary :
                                    theme.colors.primary
                            )
                            .padding(10)
                            .background(
                                Capsule()
                                    .foregroundColor(
                                        selectedTopic == topic ?
                                            theme.colors.primary :
                                            theme.colors.primaryLowContrast
                                    )
                            )
                            .padding(6)
                    }
                }
            }
        }
        .padding()
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
