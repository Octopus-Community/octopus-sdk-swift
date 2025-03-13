//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import os
import RemoteClient
import DependencyInjection
import GrpcModels

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

    nonisolated init(id: String, feedManager: FeedManager<Item>) {
        self.id = id
        self.feedManager = feedManager
    }

    public func populateWithLocalData(pageSize: Int) async {
        do {
            let result = try await feedManager.getLocalFeedItems(feedId: id, pageSize: pageSize, currentIds: [])
            hasMoreData = result.hasMoreItems
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
            hasMoreData = result.hasMoreItems
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
                try await refresh(pageSize: pageSize)

                return
            }
            isFetching = true

            let result = try await feedManager.getPreviousItems(feedId: id,
                                                                nextPageCursor: nextPageCursor, pageSize: pageSize,
                                                                currentIds: items?.map(\.id) ?? [])
            hasMoreData = result.hasMoreItems
            currentPageCursor = result.currentPageCursor
            nextPageCursor = result.nextPageCursor
            isFetching = false
            listenForItems(publisher: result.itemsPublisher)
        } catch {
            if #available(iOS 14, *) { Logger.feed.debug("An error occured during the load previous items call, loading local items instead") }
            isFetching = false
            do {
                let result = try await feedManager.getLocalFeedItems(feedId: id, pageSize: pageSize,
                                                               currentIds: items?.map(\.id) ?? [])
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
        while hasMoreData {
            if nextPageCursor == nil {
                try await refresh(pageSize: 100)
            } else {
                try await loadPreviousItems(pageSize: 100)
            }
        }
    }

    private func listenForItems(publisher: AnyPublisher<[Item], Error>) {
        feedItemsCancellable = publisher.sink(receiveCompletion: { _ in },
                       receiveValue: { [unowned self] feedItems in
            items = feedItems
        })
    }
}

extension Feed: Equatable {
    nonisolated public static func == (lhs: Feed<Item>, rhs: Feed<Item>) -> Bool {
        lhs.id == rhs.id
    }
}
