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

/// The keys the windows made by ``Feed/makeWindow(anchoredOn:)`` are stored under.
enum FeedWindowKey {
    /// Sits between a window's server feed id and the launch that made it.
    static let marker = ".window."
    /// The launch the windows made from now on belong to. The ones of a previous launch are no longer listed by any
    /// screen: ``FeedManager`` deletes them when it starts.
    static let launchId = UUID().uuidString

    static func make(serverFeedId: String) -> String {
        "\(serverFeedId)\(marker)\(launchId).\(UUID().uuidString)"
    }
}

@MainActor
public class Feed<Item: FeedItem, ChildItem: FeedItem>: @MainActor Hashable {
    let feedManager: FeedManager<Item, ChildItem>
    /// The key the feed is stored under.
    public let id: String
    /// The id the server knows the feed by: ``id``, except for a window, stored under a key of its own.
    let serverFeedId: String
    /// The item a window opens on (see ``makeWindow(anchoredOn:)``), `nil` for the other feeds.
    private let windowItemId: String?
    private var currentPageCursor: String?
    private var nextPageCursor: String?
    /// The cursor of the page before the items listed, towards the start of the feed, while it lists the window
    /// around an item.
    private var previousPageCursor: String?
    private var hasFetchedDistantOnce = false
    /// Whether ``hasMoreData`` comes from the server rather than from the stored items only.
    private var listsServerPages = false
    private var isFetching = false
    private var feedItemsCancellable: AnyCancellable?

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    @Published public private(set) var hasMoreData: Bool = true
    /// Whether the items listed reach the end of the feed as the server last listed it. Not when the feed lists the
    /// stored items only: their end is the end of what was stored, which pages not loaded yet may still follow.
    /// Up to date when ``items`` publishes.
    public var hasReachedServerEnd: Bool { listsServerPages && !hasMoreData }
    /// Whether the items listed end on the last stored one, no page of the server listed yet: nothing is left to page
    /// in, and the server may still list more items after them. Only a refresh then tells where the feed ends, when
    /// the first one failed or was ignored while another fetch was running.
    public var endsOnStoredItems: Bool { !listsServerPages && !hasMoreData }
    @Published public private(set) var items: [Item]?
    /// Whether the feed lists the window around an item and pages before it, towards the start of the feed, are still
    /// on the server. ``loadNewerItems()`` lists them.
    @Published public private(set) var hasNewerData: Bool = false
    /// The item the window opened on, while pages towards the start of the feed still separate the items listed from
    /// its first one. The feed then lists a window rather than its first page: ``refreshNewestItems(pageSize:)`` does
    /// nothing, and ``refresh(pageSize:)`` lists the window again.
    private(set) var anchorItemId: String?

    @Published private var canPublishItems: Bool = true
    private var idsInfo = [FeedItemInfoData]()

    nonisolated init(id: String, feedManager: FeedManager<Item, ChildItem>) {
        self.id = id
        self.serverFeedId = id
        self.windowItemId = nil
        self.feedManager = feedManager
    }

    private init(windowOf serverFeedId: String, anchoredOn itemId: String,
                 feedManager: FeedManager<Item, ChildItem>) {
        self.id = FeedWindowKey.make(serverFeedId: serverFeedId)
        self.serverFeedId = serverFeedId
        self.windowItemId = itemId
        self.feedManager = feedManager
    }

    deinit {
        guard windowItemId != nil else { return }
        // A window belongs to the screen that made it: nothing lists it once it is released.
        Task { [feedManager, id] in
            try? await feedManager.deleteStoredFeed(feedId: id)
        }
    }

    /// A feed of its own listing the window of this feed around the item `itemId`, for the one screen that opens on
    /// it. It is stored under a key of its own: the window never replaces what this feed stores, and no other screen
    /// lists it. What it stores is deleted once it is released. ``openWindow(pageSize:)`` lists it.
    public func makeWindow(anchoredOn itemId: String) -> Feed<Item, ChildItem> {
        Feed(windowOf: serverFeedId, anchoredOn: itemId, feedManager: feedManager)
    }

    public func populateWithLocalData(pageSize: Int) async {
        do {
            let result = try await feedManager.getLocalFeedItems(feedId: id, pageSize: pageSize, currentIds: [])
            hasMoreData = result.hasMoreData
            listsServerPages = false
            idsInfo = result.idsInfos
            listenForItems(publisher: result.itemsPublisher)
        } catch {
            if #available(iOS 14, *) { Logger.feed.debug("Error: \(error)") }
        }
    }

    public func refresh(pageSize: Int) async throws(ServerCallError) {
        try await refresh(pageSize: pageSize, keepingOlderItems: false)
    }

    /// Refreshes the newest items only, keeping the older ones the feed already holds, instead of fetching again every
    /// page ``refresh(pageSize:)`` would need to reach `pageSize`. Polling a deep feed for its new items then costs one
    /// server call. It falls back to ``refresh(pageSize:)`` when too many items came in to tell where the newest ones
    /// end. Older items deleted meanwhile stay listed until the next full refresh.
    /// - Parameter pageSize: the number of items listed once refreshed, plus the new items that came in above the
    ///   `pageSize` first ones: none of these is pushed out of the list.
    public func refreshNewestItems(pageSize: Int) async throws(ServerCallError) {
        try await refresh(pageSize: pageSize, keepingOlderItems: true)
    }

    private func refresh(pageSize: Int, keepingOlderItems: Bool) async throws(ServerCallError) {
        guard !isFetching else {
            if #available(iOS 14, *) { Logger.feed.trace("Refresh called but ignored because isFetching is true") }
            return
        }
        if let anchorItemId {
            // The first page is not the one listed: polling it would list items past a gap of items never loaded.
            guard !keepingOlderItems else { return }
            // The window belongs to the screen that opened on the item: it is listed again, not the first page.
            try await listWindow(around: anchorItemId, pageSize: pageSize)
            return
        }
        isFetching = true
        do {
            let result = try await feedManager.refreshFeed(
                feedId: id, serverFeedId: serverFeedId, pageSize: pageSize,
                keepingOlderStoredItems: keepingOlderItems && hasFetchedDistantOnce)
            if result.keptOlderStoredItems {
                // the older items kept are still paged from where the feed was, plus the stored ones past the listed page
                hasMoreData = hasMoreData || result.hasMoreData
            } else {
                hasMoreData = result.hasMoreData
                listsServerPages = true
                currentPageCursor = result.currentPageCursor
                nextPageCursor = result.nextPageCursor
            }
            idsInfo = result.idsInfos
            hasFetchedDistantOnce = true
            isFetching = false
            listenForItems(publisher: result.itemsPublisher)
        } catch {
            isFetching = false
            throw error
        }
    }

    /// Refreshes the feed once the fetch in progress, if any, has ended, instead of ignoring the call like
    /// ``refresh(pageSize:)`` does: an item the caller knows was just created is then listed when it returns. Not on a
    /// window still anchored, which lists the window around its item again, the newest items left to load.
    public func refreshWhenIdle(pageSize: Int) async throws(ServerCallError) {
        try await waitForIdle()
        try await refresh(pageSize: pageSize)
    }

    /// Lists the window around the item the feed was made for (see ``makeWindow(anchoredOn:)``) instead of its first
    /// page, once the fetch in progress, if any, has ended. The pages towards the start of the feed are then listed by
    /// ``loadNewerItems()``, the ones towards its end by ``loadPreviousItems(pageSize:)``.
    /// - Returns: whether the window holds the item. A server that cannot open the feed on it (deleted, or a server
    ///   that predates anchors) lists the first page instead. `false` for a feed that is not a window.
    @discardableResult
    public func openWindow(pageSize: Int) async throws(ServerCallError) -> Bool {
        guard let windowItemId else { return false }
        try await waitForIdle()
        return try await listWindow(around: windowItemId, pageSize: pageSize)
    }

    @discardableResult
    private func listWindow(around itemId: String, pageSize: Int) async throws(ServerCallError) -> Bool {
        isFetching = true
        do {
            let anchored = try await feedManager.refreshFeed(
                feedId: id, serverFeedId: serverFeedId, pageSize: pageSize, anchoredOn: itemId)
            hasMoreData = anchored.result.hasMoreData
            listsServerPages = true
            currentPageCursor = nil
            nextPageCursor = anchored.result.nextPageCursor
            previousPageCursor = anchored.previousPageCursor
            // A window reaching the first item is the first page: it is refreshed and polled as one.
            anchorItemId = anchored.previousPageCursor != nil ? itemId : nil
            hasNewerData = anchored.previousPageCursor != nil
            idsInfo = anchored.result.idsInfos
            hasFetchedDistantOnce = true
            isFetching = false
            listenForItems(publisher: anchored.result.itemsPublisher)
            return anchored.isAnchored
        } catch {
            isFetching = false
            throw error
        }
    }

    /// Lists the page before the items listed, towards the start of the feed, when it lists the window around an item.
    /// Once that start is listed, the feed is its first page again. A failed page stays to load.
    public func loadNewerItems() async throws(ServerCallError) {
        guard let previousPageCursor else { return }
        guard !isFetching else {
            if #available(iOS 14, *) {
                Logger.feed.trace("LoadNewerItems called but ignored because isFetching is true")
            }
            return
        }
        isFetching = true
        do {
            let newer = try await feedManager.getNewerItems(
                feedId: id, previousPageCursor: previousPageCursor, nextPageCursor: nextPageCursor, currentIds: idsInfo)
            hasMoreData = newer.result.hasMoreData
            self.previousPageCursor = newer.previousPageCursor
            if newer.previousPageCursor == nil {
                anchorItemId = nil
            }
            hasNewerData = newer.previousPageCursor != nil
            idsInfo = newer.result.idsInfos
            isFetching = false
            listenForItems(publisher: newer.result.itemsPublisher)
        } catch {
            isFetching = false
            throw error
        }
    }

    private func waitForIdle() async throws(ServerCallError) {
        while isFetching {
            do {
                try await Task.sleep(nanoseconds: 50_000_000)
            } catch {
                throw .other(error)
            }
        }
    }

    /// Lists the page after the items listed, towards the end of the feed. Ignored while a fetch is in progress. On a
    /// feed never fetched from the server yet, lists its first page instead (see ``refresh(pageSize:)``).
    /// When the call fails, the stored items after the listed ones are listed instead, ``hasMoreData`` is kept (a failed
    /// call tells nothing about the end of the feed), then the error is thrown: the page stays to load.
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
                                                                currentIds: idsInfo)
            hasMoreData = result.hasMoreData
            listsServerPages = true
            currentPageCursor = result.currentPageCursor
            nextPageCursor = result.nextPageCursor
            idsInfo = result.idsInfos
            isFetching = false
            listenForItems(publisher: result.itemsPublisher)
        } catch {
            if #available(iOS 14, *) { Logger.feed.debug("An error occured during the load previous items call, loading local items instead") }
            do {
                let result = try await feedManager.getLocalFeedItems(feedId: id, pageSize: pageSize,
                                                               currentIds: idsInfo)
                // A failed call tells nothing about the end of the feed, and the local store only knows the items
                // fetched so far: the feed stays open, so that the next load asks for the page again.
                hasMoreData = hasMoreData || result.hasMoreData
                idsInfo = result.idsInfos
                isFetching = false
                listenForItems(publisher: result.itemsPublisher)
            } catch {
                isFetching = false
                throw .other(error)
            }
            // The caller learns that the page failed: a loop asking for the pages until the end stops there instead
            // of asking again at once.
            throw error
        }
    }

    /// Fetches the pages until the end of the feed, and publishes the items once done. Throws on the first page that
    /// fails, the items fetched until then listed (see ``loadPreviousItems(pageSize:)``).
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

    /// Fetches all feed item until having fetched the item with the provided id. Throws on the first page that fails,
    /// the items fetched until then listed (see ``loadPreviousItems(pageSize:)``).
    public func fetchAll(until id: String) async throws {
        if #available(iOS 14, *) { Logger.feed.trace("Fetch all until \(id) called") }
        // If a fetch is currently happening, wait for its end
        while isFetching {
            try await Task.sleep(nanoseconds: 1)
        }
        // if the searched item is not already here and the last call has not returned any results,
        // re-do it in case their are new ones
        if !idsInfo.contains(where: { $0.itemId == id }) && !hasMoreData {
            nextPageCursor = currentPageCursor
            hasMoreData = true
        }

        // Only publish the items at the end of the loading, so it won't jump in the UI during the load of the different
        // pages. Use defer, to do it even if one call threw an error
        canPublishItems = false
        defer { canPublishItems = true }

        // A feed filled from local data only can find the item in a stale first page: reach the server once
        // before trusting it, so the items listed around the item are the current ones.
        if !hasFetchedDistantOnce {
            try await refresh(pageSize: 100)
        }

        while !idsInfo.contains(where: { $0.itemId == id }) && hasMoreData {
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

    private func listenForItems(publisher: AnyPublisher<[Item], Never>) {
        feedItemsCancellable = Publishers.CombineLatest(
            publisher,
            $canPublishItems
        ).sink { [weak self] feedItems, canPublishItems in
            // The feed can be released off the main thread while a value is queued on the main queue: the value then
            // arrives once the feed is gone, before this subscription is cancelled.
            guard let self else { return }
            if canPublishItems {
                items = feedItems
            }
        }
    }
}

extension Feed: Equatable {
    nonisolated public static func == (lhs: Feed<Item, ChildItem>, rhs: Feed<Item, ChildItem>) -> Bool {
        lhs.id == rhs.id
    }
}
