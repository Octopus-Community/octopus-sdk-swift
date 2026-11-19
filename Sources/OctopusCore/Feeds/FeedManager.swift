//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import os
import OctopusGrpcModels
import SwiftProtobuf
import OctopusDependencyInjection
import OctopusRemoteClient

class FeedManager<Item: FeedItem, ChildItem: FeedItem>: @unchecked Sendable {
    /// The most items a call fetches: a refresh of a long thread paged deep can miss thousands of them, which a single
    /// call would send back in one response.
    static var maxObjectsPerBatch: Int { 100 }
    /// The most server pages a load of the next items asks for when they only list items stored already: a few in a
    /// row are no reason to send a burst of calls.
    static var maxNextPagesPerLoad: Int { 3 }

    struct Result: @unchecked Sendable {
        let hasMoreData: Bool
        let currentPageCursor: String?
        let nextPageCursor: String?
        let idsInfos: [FeedItemInfoData]
        let itemsPublisher: AnyPublisher<[Item], Never>
        /// Whether the refresh only fetched the newest page and kept the older items stored: the paging state of the
        /// feed (its cursor, whether it has more data) is then still the one it had, and `hasMoreData` only tells
        /// whether stored items go past the page.
        var keptOlderStoredItems = false
    }

    struct AnchoredResult: @unchecked Sendable {
        let result: Result
        /// Whether the page holds the anchor item. A server that cannot open the feed on it (deleted, or a server
        /// that predates anchors) answers with the first page instead, without error.
        let isAnchored: Bool
        /// The cursor of the page that comes before the window, towards the start of the feed. Only kept when the
        /// window is anchored.
        let previousPageCursor: String?
    }

    struct NewerResult: @unchecked Sendable {
        let result: Result
        /// The cursor of the page before the ones listed, `nil` once the start of the feed is listed.
        let previousPageCursor: String?
    }

    private let feedsDatabase: FeedItemInfosDatabase
    private let authCallProvider: AuthenticatedCallProvider
    private let remoteClient: OctopusRemoteClient
    private let feedItemsDatabase: any FeedItemsDatabase<Item>
    private let childFeedItemsDatabase: (any FeedItemsDatabase<ChildItem>)?
    private let networkMonitor: NetworkMonitor

    private let getOptions: GetOptions

    typealias OctoObject = Com_Octopuscommunity_OctoObject
    typealias Aggregate = Com_Octopuscommunity_Aggregate
    typealias RequesterCtx = Com_Octopuscommunity_RequesterCtx

    private let mapper: (OctoObject, Aggregate?, RequesterCtx?) -> Item?
    private let childMapper: ((OctoObject, Aggregate?, RequesterCtx?) -> ChildItem?)?

    /// The clean-up run when the manager starts, which deletes the stored items no feed lists. Set once, in `init`.
    private var startupCleanup: Task<Void, Never>?

    init(injector: Injector,
         feedItemDatabase: any FeedItemsDatabase<Item>,
         childFeedItemDatabase: (any FeedItemsDatabase<ChildItem>)?,
         getOptions: GetOptions,
         mapper: @escaping (OctoObject, Aggregate?, RequesterCtx?) -> Item?,
         childMapper: ((OctoObject, Aggregate?, RequesterCtx?) -> ChildItem?)?) {
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        authCallProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)
        feedsDatabase = injector.getInjected(identifiedBy: Injected.feedItemInfosDatabase)
        networkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor)

        self.feedItemsDatabase = feedItemDatabase
        self.childFeedItemsDatabase = childFeedItemDatabase
        self.getOptions = getOptions
        self.mapper = mapper
        self.childMapper = childMapper

        startupCleanup = Task {
            // The windows of a previous launch are no longer listed: deleted first, they keep no item stored.
            try? await feedsDatabase.deleteWindows(exceptOfLaunch: FeedWindowKey.launchId)
            try? await cleanNonUsedFeedItems()
        }
    }

    /// Deletes what the feed `feedId` stores.
    func deleteStoredFeed(feedId: String) async throws {
        try await feedsDatabase.deleteAll(feedId: feedId)
    }

    func getLocalFeedItems(feedId: String, pageSize: Int, currentIds: [FeedItemInfoData]) async throws -> Result {
        let lastPageIdx = currentIds.count
        let feedItemInfos = try await feedsDatabase.feedItemInfos(feedId: feedId, pageSize: pageSize, lastPageIdx: lastPageIdx)
        let dateInsensitiveFeedItemInfos = feedItemInfos.map {
            FeedItemInfo(feedId: $0.feedId, itemId: $0.itemId, updateDate: Date.distantPast,
                         featuredChildId: $0.featuredChildId)
        }
        let feedItemInfoIds = feedItemInfos.map { FeedItemInfoData(from: $0) }
        let missingFeedItems = try await feedItemsDatabase.getMissingFeedItems(infos: dateInsensitiveFeedItemInfos)
        var consecutivePresentItemIds = [FeedItemInfoData]()
        for feedItemId in feedItemInfoIds {
            guard !missingFeedItems.contains(where: { $0 == feedItemId.itemId }) else {
                break
            }
            consecutivePresentItemIds.append(feedItemId)
        }
        let newIds = currentIds + consecutivePresentItemIds
        let feedItems = try await feedItemsDatabase.getFeedItems(ids: currentIds + consecutivePresentItemIds)
        let feedItemsPublisher = try feedItemsDatabase.feedItemsPublisher(ids: currentIds + consecutivePresentItemIds)
            .prepend(feedItems).eraseToAnyPublisher()
        guard !consecutivePresentItemIds.isEmpty else {
            return Result(hasMoreData: false,
                          currentPageCursor: nil, nextPageCursor: nil, idsInfos: newIds,
                          itemsPublisher: feedItemsPublisher)
        }

        let hasMoreData: Bool
        if !missingFeedItems.isEmpty {
            // if there were missing items, it means that we have no more local data
            hasMoreData = false
        } else if let nextFeedItemInfo = try await feedsDatabase.feedItemInfos(
            feedId: feedId, pageSize: 1, lastPageIdx: lastPageIdx + pageSize).first,
                  !(try await feedItemsDatabase.getFeedItems(ids: [.init(from: nextFeedItemInfo)]).isEmpty) {
            // if there is another feed item info and this next item info points to an existing item,
            // it means that we have more local data
            hasMoreData = true
        } else {
            // if there is not another feed item info or if this next item info points to a missing item,
            // it means that we have no more local data
            hasMoreData = false
        }

        return Result(hasMoreData: hasMoreData,
                      currentPageCursor: nil, nextPageCursor: nil, idsInfos: newIds,
                      itemsPublisher: feedItemsPublisher)
    }

    /// - Parameters:
    ///   - feedId: the key the feed is stored under.
    ///   - serverFeedId: the id the server knows the feed by, `feedId` unless the feed is stored under a key of its
    ///     own.
    ///   - keepingOlderStoredItems: whether to fetch the newest server page only and keep the stored items older than
    ///     it, instead of fetching again every page the size asks for. It falls back to the full refresh when the
    ///     newest page does not reach the stored items.
    func refreshFeed(feedId: String, serverFeedId: String, pageSize: Int, keepingOlderStoredItems: Bool = false)
    async throws(ServerCallError) -> Result {
        guard networkMonitor.connectionAvailable else {
            throw .noNetwork
        }
        if #available(iOS 14, *) { Logger.feed.trace("Get initial feed with page size \(pageSize)") }
        do {
            let response = try await authCallProvider.withAuthenticatedIfPossibleMethod {
                try await remoteClient.feedService.initializeFeed(feedId: serverFeedId, pageSize: 100,
                                                                  anchorItemId: nil, authenticationMethod: $0)
            }
            if #available(iOS 14, *) { Logger.feed.trace("Initialize feed done. Got \(response.items.count) results") }
            var refreshedItemInfos = response.items.map { FeedItemInfo(from: $0, feedId: feedId) }
            var nextPageCursor = response.nextPageCursor.nilIfEmpty
            if keepingOlderStoredItems, nextPageCursor != nil,
               // a fetch limit of 0 reads every stored item
               case let stored = try await feedsDatabase.feedItemInfos(feedId: feedId, pageSize: 0, lastPageIdx: 0),
               let merged = Self.mergingNewestPage(refreshedItemInfos, into: stored) {
                // No cursor: the feed keeps its own, and `hasMoreData` then tells whether stored items go past the
                // page.
                let listing = Self.listingSize(of: merged, keepingListed: stored.prefix(pageSize), atLeast: pageSize)
                var result = try await store(merged, feedId: feedId, listing: listing, nextPageCursor: nil)
                result.keptOlderStoredItems = true
                return result
            }
            // A page larger than the server's is filled from the next server pages, so a feed refreshed to the size
            // it reached by paging keeps every item it listed instead of falling back to the first server page.
            // Every page is fetched before the feed is replaced: a page failing midway leaves the feed as it was.
            while let pageCursor = nextPageCursor, Set(refreshedItemInfos.map(\.itemId)).count < pageSize {
                // Not sent again when the session changes: the cursor was handed to the session that read the first
                // page, and the feed then stays as it was.
                let nextResponse = try await remoteClient.feedService.getNextFeedPage(
                    pageCursor: pageCursor, pageSize: 100,
                    authenticationMethod: authCallProvider.authenticatedIfPossibleMethod())
                nextPageCursor = nextResponse.nextPageCursor.nilIfEmpty
                // An empty page could hand back a cursor forever: what the feed holds is all there is for now.
                if nextResponse.items.isEmpty { break }
                refreshedItemInfos += nextResponse.items.map { FeedItemInfo(from: $0, feedId: feedId) }
            }
            return try await store(refreshedItemInfos, feedId: feedId, listing: pageSize,
                                   nextPageCursor: nextPageCursor)
        } catch {
            if let error = error as? RemoteClientError {
                throw .serverError(ServerError(remoteClientError: error))
            } else {
                throw .other(error)
            }
        }
    }

    /// Replaces the stored feed with the server page around the item `anchorItemId`, instead of the first page.
    /// - Parameters:
    ///   - feedId: the key the feed is stored under.
    ///   - serverFeedId: the id the server knows the feed by.
    func refreshFeed(feedId: String, serverFeedId: String, pageSize: Int, anchoredOn anchorItemId: String)
    async throws(ServerCallError) -> AnchoredResult {
        guard networkMonitor.connectionAvailable else {
            throw .noNetwork
        }
        if #available(iOS 14, *) { Logger.feed.trace("Get feed around \(anchorItemId) with page size \(pageSize)") }
        do {
            let response = try await authCallProvider.withAuthenticatedIfPossibleMethod {
                // At most a server page, the size every other feed call asks for: a window the member grew by paging
                // is listed again around the item, the pages around it loading again as they scroll.
                try await remoteClient.feedService.initializeFeed(
                    feedId: serverFeedId, pageSize: Int32(min(pageSize, 100)), anchorItemId: anchorItemId,
                    authenticationMethod: $0)
            }
            if #available(iOS 14, *) {
                Logger.feed.trace("Initialize anchored feed done. Got \(response.items.count) results")
            }
            let itemInfos = response.items.map { FeedItemInfo(from: $0, feedId: feedId) }
            let isAnchored = itemInfos.contains { $0.itemId == anchorItemId }
            let result = try await store(itemInfos, feedId: feedId, listing: Set(itemInfos.map(\.itemId)).count,
                                         nextPageCursor: response.nextPageCursor.nilIfEmpty)
            let previousPageCursor = response.hasPreviousPageCursor ? response.previousPageCursor.nilIfEmpty : nil
            return AnchoredResult(result: result, isAnchored: isAnchored,
                                  previousPageCursor: isAnchored ? previousPageCursor : nil)
        } catch {
            if let error = error as? RemoteClientError {
                throw .serverError(ServerError(remoteClientError: error))
            } else {
                throw .other(error)
            }
        }
    }

    /// Fetches the page that comes before the listed items, towards the start of the feed, and lists it before them.
    /// - Parameters:
    ///   - previousPageCursor: the cursor ``refreshFeed(feedId:serverFeedId:pageSize:anchoredOn:)`` or this function
    ///     returned.
    ///   - nextPageCursor: the cursor of the page after the listed items, kept as it is.
    ///   - currentIds: the listed items, which are the first stored ones.
    func getNewerItems(feedId: String, previousPageCursor: String, nextPageCursor: String?,
                       currentIds: [FeedItemInfoData]) async throws(ServerCallError) -> NewerResult {
        guard networkMonitor.connectionAvailable else {
            throw .noNetwork
        }
        if #available(iOS 14, *) { Logger.feed.trace("Get newer feed page with cursor \(previousPageCursor)") }
        do {
            // Not sent again when the session changes: the cursor was handed to the session that read the window.
            let response = try await remoteClient.feedService.getNextFeedPage(
                pageCursor: previousPageCursor, pageSize: 100,
                authenticationMethod: authCallProvider.authenticatedIfPossibleMethod())
            if #available(iOS 14, *) {
                Logger.feed.trace("Get newer feed page done. Got \(response.items.count) results")
            }
            // The page comes closest first: its first item goes right before the first one listed.
            let newerItemInfos = response.items.reversed().map { FeedItemInfo(from: $0, feedId: feedId) }
            let stored = try await feedsDatabase.feedItemInfos(feedId: feedId, pageSize: 0, lastPageIdx: 0)
            let listedCount = Set(newerItemInfos.map(\.itemId) + currentIds.map(\.itemId)).count
            let result = try await store(newerItemInfos + stored, feedId: feedId, listing: listedCount,
                                         nextPageCursor: nextPageCursor)
            // An empty page could hand back a cursor forever: the start of the feed is listed for now.
            let newerPageCursor = response.items.isEmpty ? nil : response.nextPageCursor.nilIfEmpty
            return NewerResult(result: result, previousPageCursor: newerPageCursor)
        } catch {
            if let error = error as? RemoteClientError {
                throw .serverError(ServerError(remoteClientError: error))
            } else {
                throw .other(error)
            }
        }
    }

    /// Replaces the stored feed with `feedItemInfos` once the items of the first `pageSize` ones are fetched, then lists
    /// those. Items failing to load leave the stored feed as it was, the one the caller's cursors still describe. A
    /// failure once the replace has started does not: it deletes the stored infos, then inserts the new ones.
    private func store(_ feedItemInfos: [FeedItemInfo], feedId: String, listing pageSize: Int,
                       nextPageCursor: String?) async throws -> Result {
        // The items are stored before the infos that list them: the start-up clean-up would delete them in between.
        await startupCleanup?.value
        let uniqueFeedItemInfos = Self.uniqued(feedItemInfos)
        try await fetchMissingItems(of: Array(uniqueFeedItemInfos.prefix(pageSize)))
        try await replaceFeedItemInfos(with: uniqueFeedItemInfos, feedId: feedId)
        return try await listStoredItems(feedId: feedId, pageSize: pageSize, nextPageCursor: nextPageCursor)
    }

    /// The first `pageSize` items of the feed as stored.
    private func listStoredItems(feedId: String, pageSize: Int, nextPageCursor: String?) async throws -> Result {
        let feedItemInfos = try await feedsDatabase.feedItemInfos(feedId: feedId, pageSize: pageSize, lastPageIdx: 0)
        let feedItemInfoIds = feedItemInfos.map { FeedItemInfoData(from: $0) }
        let feedItems = try await feedItemsDatabase.getFeedItems(ids: feedItemInfoIds)
        let feedItemsPublisher = try feedItemsDatabase.feedItemsPublisher(ids: feedItemInfoIds)
            .prepend(feedItems).eraseToAnyPublisher()

        // there is no more items if no next item info page and there is no next local item info
        let hasMoreData: Bool
        if nextPageCursor == nil {
            hasMoreData = (try? await feedsDatabase.feedItemInfos(
                feedId: feedId, pageSize: 1, lastPageIdx: pageSize).first) != nil
        } else {
            hasMoreData = true
        }

        if #available(iOS 14, *) { Logger.feed.trace("Got \(feedItemInfoIds.count) feedItems from DB") }
        return Result(hasMoreData: hasMoreData,
                      currentPageCursor: nil, nextPageCursor: nextPageCursor, idsInfos: feedItemInfoIds,
                      itemsPublisher: feedItemsPublisher)
    }

    /// Fetches and stores the items of `feedItemInfos`, and their featured children, missing or older than the infos
    /// say.
    private func fetchMissingItems(of feedItemInfos: [FeedItemInfo]) async throws {
        let missingFeedItems = try await feedItemsDatabase.getMissingFeedItems(infos: feedItemInfos)
        // use distant past because we do not want to download the item again
        let missingChildFeedItems = try await childFeedItemsDatabase?.getMissingFeedItems(infos: feedItemInfos.compactMap {
            guard let childItemId = $0.featuredChildId else { return nil }
            return .init(feedId: $0.feedId, itemId: childItemId, updateDate: Date.distantPast, featuredChildId: nil)
        }) ?? []
        try await fetchAndStore(missingFeedItems: missingFeedItems, missingChildFeedItems: missingChildFeedItems)
    }

    /// Fetches the items `missingFeedItems` and the featured children `missingChildFeedItems`, at most
    /// ``maxObjectsPerBatch`` per server call, then stores them once every call succeeded: a call failing midway
    /// stores none of them.
    ///
    /// The calls are one read: a session change during any of them sends them all again with the new session, instead
    /// of storing together items read by two sessions.
    private func fetchAndStore(missingFeedItems: [String], missingChildFeedItems: [String]) async throws {
        let allMissingItems = missingFeedItems + missingChildFeedItems
        guard !allMissingItems.isEmpty else { return }
        if #available(iOS 14, *) { Logger.feed.trace("Missing \(allMissingItems.count) feedItems, fetching them") }
        let responses = try await authCallProvider.withAuthenticatedIfPossibleMethod { authenticationMethod in
            var responses = [String: Com_Octopuscommunity_GetResponse]()
            for batch in allMissingItems.chunked(into: Self.maxObjectsPerBatch) {
                let batchResponse = try await remoteClient.octoService.getBatch(
                    octoObjectInfos: batch.map { OctoObjectInfo(id: $0, hasVideo: false) }, // set hasVideo to false is ok because we don't register the view
                    options: getOptions,
                    incrementViewCount: false,
                    authenticationMethod: authenticationMethod)
                for response in batchResponse.responses where responses[response.octoObjectID] == nil {
                    responses[response.octoObjectID] = response
                }
            }
            return responses
        }

        let feedItems = missingFeedItems.compactMap { feedItemId -> Item? in
            guard let response = responses[feedItemId], response.hasOctoObject else { return nil }
            let aggregate = response.hasAggregate ? response.aggregate : nil
            let requesterCtx = response.hasRequesterCtx ? response.requesterCtx : nil
            return mapper(response.octoObject, aggregate, requesterCtx)
        }
        try await feedItemsDatabase.upsert(feedItems: feedItems)

        let childFeedItems = missingChildFeedItems.compactMap { feedItemId -> ChildItem? in
            guard let response = responses[feedItemId], response.hasOctoObject else { return nil }
            let aggregate = response.hasAggregate ? response.aggregate : nil
            let requesterCtx = response.hasRequesterCtx ? response.requesterCtx : nil
            return childMapper?(response.octoObject, aggregate, requesterCtx)
        }
        try await childFeedItemsDatabase?.upsert(feedItems: childFeedItems)
    }

    /// The item infos of a feed whose newest server page was fetched again: that page, then the stored items older than
    /// its last one. `nil` when the stored items do not hold that last one: too many items came in since to tell where
    /// the page ends among them.
    static func mergingNewestPage(_ newestPage: [FeedItemInfo], into stored: [FeedItemInfo]) -> [FeedItemInfo]? {
        guard let last = newestPage.last,
              let lastIndex = stored.firstIndex(where: { $0.itemId == last.itemId }) else { return nil }
        return newestPage + stored[(lastIndex + 1)...]
    }

    /// The number of items to list from `merged` so that the items `listed` before the refresh all stay listed: the
    /// new items come in above them, and listing `pageSize` items only would push the oldest ones out, shifting the
    /// screen of a member reading them on every poll that brings new items. At least `pageSize`.
    static func listingSize(of merged: [FeedItemInfo], keepingListed listed: ArraySlice<FeedItemInfo>,
                            atLeast pageSize: Int) -> Int {
        let listedIds = Set(listed.map(\.itemId))
        guard let lastListedIndex = uniqued(merged).lastIndex(where: { listedIds.contains($0.itemId) }) else {
            return pageSize
        }
        return max(pageSize, lastListedIndex + 1)
    }

    func getPreviousItems(feedId: String, nextPageCursor: String?, pageSize: Int, currentIds: [FeedItemInfoData])
    async throws(ServerCallError) -> Result {
        guard networkMonitor.connectionAvailable else {
            throw .noNetwork
        }
        do {
            var newCurrentPageCursor = nextPageCursor
            var newNextPageCursor = nextPageCursor
            let lastPageIdx = currentIds.count
            if #available(iOS 14, *) {
                Logger.feed.trace("Get feed with cursor \(nextPageCursor ?? "nil") from \(lastPageIdx) to \(lastPageIdx + pageSize)")
            }
            var feedItemInfos = try await feedsDatabase.feedItemInfos(feedId: feedId, pageSize: pageSize, lastPageIdx: lastPageIdx)
            // A page can list only items stored already: the feed changed since the previous one, or a call that
            // failed on the items of the page stored it without moving the feed's cursor past it. The next page is
            // then asked for in the same load, which would otherwise list nothing.
            var fetchedPages = 0
            while feedItemInfos.count < pageSize, let pageCursor = newNextPageCursor,
                  fetchedPages == 0 || (feedItemInfos.isEmpty && fetchedPages < Self.maxNextPagesPerLoad) {
                if #available(iOS 14, *) {
                    Logger.feed.trace("Not enough feed itemInfos \(feedItemInfos.count) for page, fetching next page")
                }
                let response: Com_Octopuscommunity_GetFeedPageResponse
                // Not sent again when the session changes: the cursor was handed to the session that read the
                // previous page.
                response = try await remoteClient.feedService.getNextFeedPage(
                    pageCursor: pageCursor, pageSize: 100,
                    authenticationMethod: authCallProvider.authenticatedIfPossibleMethod())
                if #available(iOS 14, *) { Logger.feed.trace("Get next feed page done. Got \(response.items.count) results") }
                fetchedPages += 1

                newCurrentPageCursor = pageCursor
                newNextPageCursor = try await saveFeedItemInfosResponse(response, feedId: feedId, replaceInDb: false)
                feedItemInfos = try await feedsDatabase.feedItemInfos(feedId: feedId, pageSize: pageSize, lastPageIdx: lastPageIdx)
                if #available(iOS 14, *) { Logger.feed.trace("Got \(feedItemInfos.count) feedItemsInfos from DB") }
                // An empty page could hand back a cursor forever: the next load asks for it, not this one.
                if response.items.isEmpty { break }
            }

            let feedItemInfoIds = feedItemInfos.map { FeedItemInfoData(from: $0) }
            let missingFeedItems = try await feedItemsDatabase.getMissingFeedItems(infos: feedItemInfos)
            // use distant future because we do not want to download the item again
            let missingChildFeedItems = try await childFeedItemsDatabase?.getMissingFeedItems(infos: feedItemInfos.compactMap {
                guard let childItemId = $0.featuredChildId else { return nil }
                return .init(feedId: $0.feedId, itemId: childItemId, updateDate: Date.distantFuture, featuredChildId: nil)
            }) ?? []
            try await fetchAndStore(missingFeedItems: missingFeedItems, missingChildFeedItems: missingChildFeedItems)
            let newIds = currentIds + feedItemInfoIds
            let feedItems = try await feedItemsDatabase.getFeedItems(ids: newIds)
            let feedItemsPublisher = try feedItemsDatabase.feedItemsPublisher(ids: newIds)
                .prepend(feedItems).eraseToAnyPublisher()

            // there is no more items if no next item info page and there is no next local item info
            let hasMoreData: Bool
            if newNextPageCursor == nil {
                hasMoreData = (try? await feedsDatabase.feedItemInfos(
                    feedId: feedId, pageSize: 1, lastPageIdx: lastPageIdx + pageSize).first) != nil
            } else {
                hasMoreData = true
            }

            if #available(iOS 14, *) { Logger.feed.trace("Got \(feedItemInfoIds.count) feedItems from DB") }
            return Result(hasMoreData: hasMoreData,
                          currentPageCursor: newCurrentPageCursor,
                          nextPageCursor: newNextPageCursor,
                          idsInfos: newIds,
                          itemsPublisher: feedItemsPublisher)
        } catch {
            if let error = error as? RemoteClientError {
                throw .serverError(ServerError(remoteClientError: error))
            } else {
                throw .other(error)
            }
        }
    }

    private func saveFeedItemInfosResponse(_ response: Com_Octopuscommunity_GetFeedPageResponse, feedId: String, replaceInDb: Bool) async throws -> String? {
        let newFeedItemInfos = response.items.map { FeedItemInfo(from: $0, feedId: feedId) }
        if replaceInDb {
            try await feedsDatabase.deleteAll(feedId: feedId) // TODO: see if we can do it in one transaction with the upsert
        }
        try await feedsDatabase.upsert(feedItemInfos: newFeedItemInfos, feedId: feedId)

        return response.nextPageCursor.nilIfEmpty
    }

    /// Replaces the feed's item infos with the given ones, in order. An item listed twice, as two server pages may
    /// do while the feed changes, keeps its first place.
    private func replaceFeedItemInfos(with feedItemInfos: [FeedItemInfo], feedId: String) async throws {
        try await feedsDatabase.deleteAll(feedId: feedId) // TODO: see if we can do it in one transaction with the upsert
        try await feedsDatabase.upsert(feedItemInfos: Self.uniqued(feedItemInfos), feedId: feedId)
    }

    /// `feedItemInfos` without the items listed twice, which keep their first place.
    private static func uniqued(_ feedItemInfos: [FeedItemInfo]) -> [FeedItemInfo] {
        var listedIds = Set<String>()
        return feedItemInfos.filter { listedIds.insert($0.itemId).inserted }
    }

    private func cleanNonUsedFeedItems() async throws {
        let itemIds = try await feedsDatabase.getAllItemIds()
        try await feedItemsDatabase.deleteAll(except: itemIds)
    }
}
