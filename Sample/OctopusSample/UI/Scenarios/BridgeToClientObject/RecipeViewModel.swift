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
    @Published var isLoading = false
    @Published var error: Error?

    @Published private(set) var post: OctopusPost?

    private var storage = [AnyCancellable]()

    private let octopus: OctopusSDK = OctopusSDKProvider.instance.octopus
    private var topicCancellable: AnyCancellable?
    private var topics: [Topic] = []

    init(recipe: Recipe) {
        // Listen to SDK topics changes
        topicCancellable = octopus.$topics.sink { [unowned self] in
            self.topics = $0
        }

        // Ask to update the topics
        Task {
            try await octopus.fetchTopics()
            await getBridgePost(recipe: recipe)
        }

        octopus.getClientObjectRelatedPostPublisher(clientObjectId: recipe.id)
            .sink { [unowned self] post in
                self.post = post
            }.store(in: &storage)
    }

    func getBridgePost(recipe: Recipe) {
        isLoading = true
        Task {
            await getBridgePost(recipe: recipe)
            isLoading = false
        }
    }

    func getBridgePost(recipe: Recipe) async {
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

        let signature: String? = switch SDKConfigManager.instance.sdkConfig?.authKind {
        case .sso: try? TokenProvider().getBridgeSignature()
        default: nil
        }

        do {
            post = try await octopus.fetchOrCreateClientObjectRelatedPost(
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
                    signature: signature
                )
            )
        } catch {
            self.error = error
        }
    }
}
