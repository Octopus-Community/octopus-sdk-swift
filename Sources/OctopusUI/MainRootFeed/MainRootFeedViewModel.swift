//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus
import OctopusCore

@MainActor
class MainRootFeedViewModel: ObservableObject {
    @Published var mainRootFeed: RootFeed?
    @Published private(set) var error: DisplayableString?

    let octopus: OctopusSDK

    private var storage = [AnyCancellable]()

    init(octopus: OctopusSDK) {
        self.octopus = octopus

        octopus.core.rootFeedsRepository.getRootFeeds()
            .replaceError(with: [])
            .sink { [unowned self] in
                mainRootFeed = $0.first
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
