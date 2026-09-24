//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus
import OctopusCore
import os

@MainActor
class MainRootFeedViewModel: ObservableObject {
    @Published var mainRootFeed: RootFeed?
    @Published private(set) var error: DisplayableString?
    /// Set when the feeds themselves fail to load, i.e. when there is not even a feed to display posts
    /// in. Without it the screen would stay blank with nothing to act on (Screen states spec).
    @Published private(set) var loadFailure: ScreenStateFailure?

    let octopus: OctopusSDK

    private var storage = [AnyCancellable]()

    init(octopus: OctopusSDK) {
        self.octopus = octopus

        octopus.core.rootFeedsRepository.getRootFeeds()
            .sink { [unowned self] in
                mainRootFeed = $0.first
                // A cached feed arriving after a failed fetch makes the error state moot.
                if mainRootFeed != nil { loadFailure = nil }
            }.store(in: &storage)

        fetchRootFeeds()
    }

    /// Re-runs the first load after a failure.
    func retryFirstLoad() {
        loadFailure = nil
        fetchRootFeeds()
    }

    private func fetchRootFeeds() {
        Task {
            do {
                try await octopus.core.rootFeedsRepository.fetchRootFeeds()
                loadFailure = nil
            } catch {
                if #available(iOS 14, *) { Logger.feed.debug("Error while fetching root feeds: \(error)") }
                // `fetchRootFeeds` throws an untyped error, so anything that is not a server call is
                // folded into the neutral catch-all.
                let serverCallError = error as? ServerCallError
                if mainRootFeed == nil {
                    loadFailure = serverCallError.map { ScreenStateFailure($0) } ?? .other
                } else if let serverCallError, case .serverError(.notAuthenticated) = serverCallError {
                    self.error = serverCallError.displayableMessage
                }
            }
        }
    }
}
