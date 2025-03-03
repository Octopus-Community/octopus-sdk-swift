//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus
import OctopusCore

@MainActor
class RootFeedsViewModel: ObservableObject {
    @Published private(set) var rootFeeds: [RootFeed] = []
    @Published var selectedRootFeed: RootFeed?
    @Published private(set) var error: DisplayableString?

    let octopus: OctopusSDK

    private var storage = [AnyCancellable]()

    init(octopus: OctopusSDK) {
        self.octopus = octopus

        octopus.core.rootFeedsRepository.getRootFeeds()
            .replaceError(with: [])
            .sink { [unowned self] in
                // the first time, select the first root feed
                if selectedRootFeed == nil {
                    selectedRootFeed = $0.first
                }
                rootFeeds = $0
            }.store(in: &storage)

        octopus.core.postsRepository.postSentPublisher.sink { [unowned self] in
            if let mainRootFeed = rootFeeds.first {
                selectedRootFeed = mainRootFeed
            }
        }.store(in: &storage)

        Task {
            do {
                try await octopus.core.rootFeedsRepository.fetchRootFeeds()
            } catch {
               if let error = error as? ServerCallError, case .serverError(.notAuthenticated) = error {
                   self.error = error.displayableMessage
               }
           }
        }
    }
}
