//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import XCTest
import Combine
import OctopusDependencyInjection
import OctopusGrpcModels
@testable import OctopusRemoteClient
@testable import OctopusCore

final class RootFeedsRepositoryTests: XCTestCase {
    private var rootFeedsRepository: RootFeedsRepository!
    private var mockFeedService: MockFeedService!
    private var injector: Injector!
    private var storage = [AnyCancellable]()

    override func setUp() {
        injector = Injector()
        injector.register { _ in try! ModelCoreDataStack(inRam: true) }
        injector.registerMocks(.remoteClient, .networkMonitor, .authProvider, .blockedUserIdsProvider)
        injector.register { RootFeedsDatabase(injector: $0) }
        injector.register { PostFeedsStore(injector: $0) }
        injector.register { CommentFeedsStore(injector: $0) }
        injector.register { ReplyFeedsStore(injector: $0) }
        injector.register { RepliesDatabase(injector: $0) }
        injector.register { CommentsDatabase(injector: $0) }
        injector.register { PostsDatabase(injector: $0) }
        injector.register { FeedItemInfosDatabase(injector: $0) }

        rootFeedsRepository = RootFeedsRepository(injector: injector)
        mockFeedService = (injector.getInjected(identifiedBy: Injected.remoteClient).feedService as! MockFeedService)
    }

    /// Opening the community while the member is being signed in (right after a community switch, for instance)
    /// used to leave the feed on an error: the root feeds response came back for the previous session.
    func testRootFeedsAreFetchedWhenTheSessionChangedDuringTheCall() async throws {
        mockFeedService.injectNextGetRootFeedsInfoError(.unknown(RefreshingTokenError.userIdNotMatching))
        mockFeedService.injectNextGetRootFeedsInfo(.with {
            $0.feedsInfo = [.with {
                $0.id = "feed-1"
                $0.label = "Feed 1"
            }]
        })

        try await rootFeedsRepository.fetchRootFeeds()

        let rootFeedsStored = expectation(description: "Root feeds stored")
        rootFeedsRepository.getRootFeeds()
            .sink { rootFeeds in
                if rootFeeds.map(\.feedId) == ["feed-1"] { rootFeedsStored.fulfill() }
            }
            .store(in: &storage)
        await fulfillment(of: [rootFeedsStored], timeout: 1)
    }
}
