//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine

protocol FeedItemsDatabase<FeedItem> {
    associatedtype FeedItem

    func getMissingFeedItems(infos: [FeedItemInfo]) async throws -> [String]
    func getFeedItems(ids: [FeedItemInfoData]) async throws -> [FeedItem]
    func feedItemsPublisher(ids: [FeedItemInfoData]) throws -> AnyPublisher<[FeedItem], Error>
    func upsert(feedItems: [FeedItem]) async throws
    func deleteAll(except ids: [String]) async throws
}
