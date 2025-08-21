//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import os
import OctopusRemoteClient
import OctopusDependencyInjection
import OctopusGrpcModels

public protocol FeedItem: Equatable, Sendable {
    var id: String { get }
}

@MainActor
public class Feed<Item: FeedItem> {
    let feedManager: FeedManager<Item>
    public let id: String
    private var currentPageCursor: String?
    private var nextPageCursor: String?
    private var hasFetchedDistantOnce = false
    private var isFetching = false
    private var feedItemsCancellable: AnyCancellable?

    @Published public private(set) var hasMoreData: Bool = true
    @Published public private(set) var items: [Item]?

    @Published private var canPublishItems: Bool = true
    @Published private var internalItems: [Item]?

    nonisolated init(id: String, feedManager: FeedManager<Item>) {
        self.id = id
        self.feedManager = feedManager
    }

    public func populateWithLocalData(pageSize: Int) async {
        do {
            let result = try await feedManager.getLocalFeedItems(feedId: id, pageSize: pageSize, currentIds: [])
            hasMoreData = result.hasMoreData
            listenForItems(publisher: result.itemsPublisher)
        } catch {
            if #available(iOS 14, *) { Logger.feed.debug("Error: \(error)") }
        }
    }

    public func refresh(pageSize: Int) async throws(ServerCallError) {
        guard !isFetching else {
            if #available(iOS 14, *) { Logger.feed.trace("Refresh called but ignored because isFetching is true") }
            return
        }
        isFetching = true
        do {
            let result = try await feedManager.refreshFeed(feedId: id, pageSize: pageSize)
            hasMoreData = result.hasMoreData
            currentPageCursor = result.currentPageCursor
            nextPageCursor = result.nextPageCursor
            hasFetchedDistantOnce = true
            isFetching = false
            listenForItems(publisher: result.itemsPublisher)
        } catch {
            isFetching = false
            throw error
        }
    }

    public func loadPreviousItems(pageSize: Int) async throws(ServerCallError) {
        guard !isFetching else {
            if #available(iOS 14, *) { Logger.feed.trace("LoadPreviousItems called but ignored because isFetching is true") }
            return
        }
        do {
            if !hasFetchedDistantOnce {
                if #available(iOS 14, *) { Logger.feed.trace("Calling load previous but not called refresh before") }
                return try await refresh(pageSize: pageSize)
            }
            isFetching = true
            let result = try await feedManager.getPreviousItems(feedId: id,
                                                                nextPageCursor: nextPageCursor, pageSize: pageSize,
                                                                currentIds: internalItems?.map(\.id) ?? [])
            hasMoreData = result.hasMoreData
            currentPageCursor = result.currentPageCursor
            nextPageCursor = result.nextPageCursor
            isFetching = false
            listenForItems(publisher: result.itemsPublisher)
        } catch {
            if #available(iOS 14, *) { Logger.feed.debug("An error occured during the load previous items call, loading local items instead") }
            isFetching = false
            do {
                let result = try await feedManager.getLocalFeedItems(feedId: id, pageSize: pageSize,
                                                               currentIds: internalItems?.map(\.id) ?? [])
                listenForItems(publisher: result.itemsPublisher)
            } catch {
                throw .other(error)
            }
        }
    }

    public func fetchAll() async throws {
        if #available(iOS 14, *) { Logger.feed.trace("Fetch all called") }
        // If a fetch is currently happening, wait for its end
        while isFetching {
            try await Task.sleep(nanoseconds: 1)
        }
        // if the last call has not returned any results, re-do it in case their are new ones
        if !hasMoreData {
            nextPageCursor = currentPageCursor
            hasMoreData = true
        }
        // Only publish the items at the end of the loading, so it won't jump in the UI during the load of the different
        // pages. Use defer, to do it even if one call threw an error
        canPublishItems = false
        defer { canPublishItems = true }

        while hasMoreData {
            if nextPageCursor == nil {
                try await refresh(pageSize: 100)
                // if it has more data, directly do the loadPreviousItem to cover the case where there is no more
                // distant items infos (i.e. nextPageCursor is nil) but there are more items to fetch
                if hasMoreData {
                    try await loadPreviousItems(pageSize: 100)
                }
            } else {
                try await loadPreviousItems(pageSize: 100)
            }
        }
    }
    
    /// Fetches all feed item until having fetched the item with the provided id
    public func fetchAll(until id: String) async throws {
        if #available(iOS 14, *) { Logger.feed.trace("Fetch all until \(id) called") }
        // If a fetch is currently happening, wait for its end
        while isFetching {
            try await Task.sleep(nanoseconds: 1)
        }
        // if the searched item is not already here and the last call has not returned any results,
        // re-do it in case their are new ones
        if !(internalItems?.contains(where: { $0.id == id }) ?? false) && !hasMoreData {
            nextPageCursor = currentPageCursor
            hasMoreData = true
        }

        // Only publish the items at the end of the loading, so it won't jump in the UI during the load of the different
        // pages. Use defer, to do it even if one call threw an error
        canPublishItems = false
        defer { canPublishItems = true }

        while !(internalItems?.contains(where: { $0.id == id }) ?? false) && hasMoreData {
            if nextPageCursor == nil {
                try await refresh(pageSize: 100)
                // if it has more data, directly do the loadPreviousItem to cover the case where there is no more
                // distant items infos (i.e. nextPageCursor is nil) but there are more items to fetch
                if hasMoreData {
                    try await loadPreviousItems(pageSize: 100)
                }
            } else {
                try await loadPreviousItems(pageSize: 100)
            }
        }
    }


    private func listenForItems(publisher: AnyPublisher<[Item], Error>) {
        feedItemsCancellable = Publishers.CombineLatest(
            publisher.replaceError(with: []),
            $canPublishItems
        ).sink { [unowned self] feedItems, canPublishItems in
            internalItems = feedItems
            if canPublishItems {
                items = internalItems
            }
        }
    }
}

extension Feed: Equatable {
    nonisolated public static func == (lhs: Feed<Item>, rhs: Feed<Item>) -> Bool {
        lhs.id == rhs.id
    }
}
