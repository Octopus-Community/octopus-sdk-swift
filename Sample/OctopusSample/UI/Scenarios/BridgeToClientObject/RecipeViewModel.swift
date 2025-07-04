//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus

/// A view model that displays a recipe and get (or create) the Octopus post related to the recipe
@MainActor
class RecipeViewModel: ObservableObject {
    @Published private(set) var octopus: OctopusSDK?
    @Published var octopusPostId: String?
    @Published var isLoading = false
    @Published var error: Error?

    private var storage = [AnyCancellable]()

    private let octopusSDKProvider = OctopusSDKProvider.instance

    private var topicCancellable: AnyCancellable?
    private var topics: [Topic] = []

    init() {
        octopusSDKProvider.$octopus
            .sink { [unowned self] in
                octopus = $0

                guard let octopus else { return }
                // Listen to SDK topics changes
                topicCancellable = octopus.$topics.sink { [unowned self] in
                    self.topics = $0
                }
                // Ask to update the topics
                Task {
                    try await octopus.fetchTopics()
                }
            }.store(in: &storage)
    }

    func getBridgePostId(recipe: Recipe) {
        isLoading = true
        Task {
            await getBridgePostId(recipe: recipe)
            isLoading = false
        }
    }

    func getBridgePostId(recipe: Recipe) async {
        // convert the image into an SDK Attachement
        let attachment: ClientPost.Attachment? = switch recipe.img {
        case let .local(imgResource):
                .localImage(UIImage(resource: imgResource).jpegData(compressionQuality: 1.0)!)
        case let .remote(url):
                .distantImage(url)
        case .none: nil
        }

        // Example of how to use the topics API: match the topic name to get the topic id
        let topicId: String? = if let topicName = recipe.topicName {
            topics.first(where: { $0.name == topicName })?.id
        } else { nil }
        do {
            let postId = try await octopus?.getOrCreateClientObjectRelatedPostId(
                content: ClientPost(
                    clientObjectId: recipe.id,
                    topicId: topicId,
                    text: recipe.title,
                    catchPhrase: recipe.octopusCatchPhrase,
                    attachment: attachment,
                    viewClientObjectButtonText: recipe.octopusViewClientObjectButtonText,
                    // you should use a signature if your community configuration requires it. We recommand configuring
                    // your community to require a signature for security reasons.
                    // An example of how the signature might be constructed is available in `TokenProvider` (without the
                    // need of the `sub` info in the token), but it is safer if it is your backend that provides the
                    // signature.
                    signature: nil
                )
            )
            octopusPostId = postId
        } catch {
            self.error = error
        }
    }
}
