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
    private var groupsCancellable: AnyCancellable?
    private var groups: [OctopusGroup] = []

    init(recipe: Recipe) {
        // Listen to SDK groups changes
        groupsCancellable = octopus.$groups.sink { [unowned self] in
            self.groups = $0
        }

        // Ask to update the groups
        Task {
            try? await octopus.fetchGroups()
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

    func set(reaction: OctopusReactionKind?) {
        Task {
            do {
                guard let post else { throw NSError(domain: "No post to react to", code: 1) }
                try await octopus.set(reaction: reaction, clientObjectRelatedPostId: post.id)
            } catch {
                self.error = error
            }
        }
    }

    private func getBridgePost(recipe: Recipe) async {
        // convert the image into an SDK Attachement
        let attachment: ClientPost.Attachment? = switch recipe.img {
        case let .local(imgResource):
                .localImage(UIImage(resource: imgResource).jpegData(compressionQuality: 1.0)!)
        case let .remote(url):
                .distantImage(url)
        case .none: nil
        }

        // Example of how to use the groups API: match the group name to get the group id
        let groupId: String? = if let topicName = recipe.topicName {
            groups.first(where: { $0.name == topicName })?.id
        } else { nil }

        do {
            post = try await octopus.fetchOrCreateClientObjectRelatedPost(
                content: ClientPost(
                    clientObjectId: recipe.id,
                    groupId: groupId,
                    text: recipe.title,
                    catchPhrase: recipe.octopusCatchPhrase,
                    attachment: attachment,
                    viewClientObjectButtonText: recipe.octopusViewClientObjectButtonText
                ),
                tokenProvider: { bridgeFingerprint in
                    // you should use a signature if your community configuration requires it. We recommand configuring
                    // your community to require a signature for security reasons.
                    // An example of how the signature might be constructed is available in `TokenProvider`,
                    // but it is safer if it is your backend that provides the signature.
                    let signature: String? = switch SDKConfigManager.instance.sdkConfig?.authKind {
                    case .sso: try TokenProvider().getBridgeSignature(bridgeFingerprint: bridgeFingerprint)
                    default: nil
                    }
                    return signature
                }
            )
        } catch {
            self.error = error
        }
    }
}
