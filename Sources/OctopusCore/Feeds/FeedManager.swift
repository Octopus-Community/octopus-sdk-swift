//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import os
import GrpcModels
import SwiftProtobuf
import DependencyInjection
import RemoteClient

class FeedManager<Item: FeedItem>: @unchecked Sendable {

    struct Result: @unchecked Sendable {
        let hasMoreItems: Bool
        let currentPageCursor: String?
        let nextPageCursor: String?
        let itemsPublisher: AnyPublisher<[Item], Error>
    }

    private let feedsDatabase: FeedItemInfosDatabase
    private let authCallProvider: AuthenticatedCallProvider
    private let remoteClient: RemoteClient
    private let feedItemsDatabase: any FeedItemsDatabase<Item>
    private let networkMonitor: NetworkMonitor

    private let getOptions: GetOptions

    typealias OctoObject = Com_Octopuscommunity_OctoObject
    typealias Aggregate = Com_Octopuscommunity_Aggregate
    typealias RequesterCtx = Com_Octopuscommunity_RequesterCtx

    private let mapper: (OctoObject, Aggregate?, RequesterCtx?) -> Item?

    init(injector: Injector, feedItemDatabase: any FeedItemsDatabase<Item>, getOptions: GetOptions,
         mapper: @escaping (OctoObject, Aggregate?, RequesterCtx?) -> Item?) {
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        authCallProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)
        feedsDatabase = injector.getInjected(identifiedBy: Injected.feedItemInfosDatabase)
        networkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor)

        self.feedItemsDatabase = feedItemDatabase
        self.getOptions = getOptions
        self.mapper = mapper

        Task {
            try? await cleanNonUsedFeedItems()
        }
    }

    func getLocalFeedItems(feedId: String, pageSize: Int, currentIds: [String]) async throws -> Result {
        let lastPageIdx = currentIds.count
        let feedItemInfos = try await feedsDatabase.feedItemInfos(feedId: feedId, pageSize: pageSize, lastPageIdx: lastPageIdx)
        let dateInsensitiveFeedItemInfos = feedItemInfos.map {
            FeedItemInfo(feedId: $0.feedId, itemId: $0.itemId, updateDate: Date.distantPast)
        }
        let feedItemInfoIds = feedItemInfos.map { $0.itemId }
        let missingFeedItems = try await feedItemsDatabase.getMissingFeedItems(infos: dateInsensitiveFeedItemInfos)
        var consecutivePresentItemIds = [String]()
        for feedItemId in feedItemInfoIds {
            guard !missingFeedItems.contains(feedItemId) else {
                break
            }
            consecutivePresentItemIds.append(feedItemId)
        }
        guard !consecutivePresentItemIds.isEmpty else {
            return Result(hasMoreItems: false, currentPageCursor: nil, nextPageCursor: nil,
                          itemsPublisher: Just([]).setFailureType(to: Error.self).eraseToAnyPublisher())
        }
        let feedItems = try await feedItemsDatabase.getFeedItems(ids: currentIds + feedItemInfoIds)
        let feedItemsPublisher = try feedItemsDatabase.feedItemsPublisher(ids: currentIds + feedItemInfoIds)
            .prepend(feedItems).eraseToAnyPublisher()

        let hasMoreItems: Bool
        if !missingFeedItems.isEmpty {
            // if there were missing items, it means that we have no more local data
            hasMoreItems = false
        } else if let nextFeedItemInfo = try await feedsDatabase.feedItemInfos(
            feedId: feedId, pageSize: 1, lastPageIdx: lastPageIdx + pageSize).first,
                  !(try await feedItemsDatabase.getFeedItems(ids: [nextFeedItemInfo.itemId]).isEmpty) {
            // if there is another feed item info and this next item info points to an existing item,
            // it means that we have more local data
            hasMoreItems = true
        } else {
            // if there is not another feed item info or if this next item info points to a missing item,
            // it means that we have no more local data
            hasMoreItems = false
        }

        return Result(hasMoreItems: hasMoreItems, currentPageCursor: nil, nextPageCursor: nil,
                      itemsPublisher: feedItemsPublisher)
    }

    func refreshFeed(feedId: String, pageSize: Int) async throws(ServerCallError) -> Result {
        guard networkMonitor.connectionAvailable else {
            throw .noNetwork
        }
        if #available(iOS 14, *) { Logger.feed.trace("Get initial feed with page size \(pageSize)") }
        do {
            let response = try await remoteClient.feedService.initializeFeed(
                feedId: feedId, pageSize: 100,
                authenticationMethod: authCallProvider.authenticatedIfPossibleMethod())
            if #available(iOS 14, *) { Logger.feed.trace("Initialize feed done. Got \(response.items.count) results") }
            let nextPageCursor = try await saveFeedItemInfosResponse(response, feedId: feedId, replaceInDb: true)

            let feedItemInfos = try await feedsDatabase.feedItemInfos(feedId: feedId, pageSize: pageSize, lastPageIdx: 0)
            let feedItemInfoIds = feedItemInfos.map { $0.itemId }
            let missingFeedItems = try await feedItemsDatabase.getMissingFeedItems(infos: feedItemInfos)
            if !missingFeedItems.isEmpty {
                if #available(iOS 14, *) { Logger.feed.trace("Missing \(missingFeedItems.count) feedItems, fetching them") }
                let batchResponse = try await remoteClient.octoService.getBatch(
                    ids: missingFeedItems,
                    options: getOptions,
                    incrementViewCount: false,
                    authenticationMethod: authCallProvider.authenticatedIfPossibleMethod())
                let feedItems = batchResponse.responses.compactMap { response -> Item? in
                    guard response.hasOctoObject else { return nil }
                    let aggregate = response.hasAggregate ? response.aggregate : nil
                    let requesterCtx = response.hasRequesterCtx ? response.requesterCtx : nil
                    return mapper(response.octoObject, aggregate, requesterCtx)
                }
                try await feedItemsDatabase.upsert(feedItems: feedItems)
            }
            let feedItems = try await feedItemsDatabase.getFeedItems(ids: feedItemInfoIds)
            let feedItemsPublisher = try feedItemsDatabase.feedItemsPublisher(ids: feedItemInfoIds)
                .prepend(feedItems).eraseToAnyPublisher()

            // there is no more items if no next item info page and there is no next local item info
            let hasMoreItems: Bool
            if nextPageCursor == nil {
                hasMoreItems = (try? await feedsDatabase.feedItemInfos(
                    feedId: feedId, pageSize: 1, lastPageIdx: pageSize).first) != nil
            } else {
                hasMoreItems = true
            }

            if #available(iOS 14, *) { Logger.feed.trace("Got \(feedItemInfoIds.count) feedItems from DB") }
            return Result(hasMoreItems: hasMoreItems, currentPageCursor: nil, nextPageCursor: nextPageCursor,
                          itemsPublisher: feedItemsPublisher)
        } catch {
            if let error = error as? RemoteClientError {
                throw .serverError(ServerError(remoteClientError: error))
            } else {
                throw .other(error)
            }
        }
    }

    func getPreviousItems(feedId: String, nextPageCursor: String?, pageSize: Int, currentIds: [String])
    async throws(ServerCallError) -> Result {
        guard networkMonitor.connectionAvailable else {
            throw .noNetwork
        }
        do {
            var newNextPageCursor = nextPageCursor
            let lastPageIdx = currentIds.count
            if #available(iOS 14, *) {
                Logger.feed.trace("Get feed with cursor \(nextPageCursor ?? "nil") from \(lastPageIdx) to \(lastPageIdx + pageSize)")
            }
            var feedItemInfos = try await feedsDatabase.feedItemInfos(feedId: feedId, pageSize: pageSize, lastPageIdx: lastPageIdx)
            if feedItemInfos.count < pageSize, let nextPageCursor { // TODO: add a while to get all missing pages
                if #available(iOS 14, *) {
                    Logger.feed.trace("Not enough feed itemInfos \(feedItemInfos.count) for page, fetching next page")
                }
                let response: Com_Octopuscommunity_GetFeedPageResponse
                response = try await remoteClient.feedService.getNextFeedPage(
                    pageCursor: nextPageCursor, pageSize: 100,
                    authenticationMethod: authCallProvider.authenticatedIfPossibleMethod())
                if #available(iOS 14, *) { Logger.feed.trace("Get next feed page done. Got \(response.items.count) results") }

                newNextPageCursor = try await saveFeedItemInfosResponse(response, feedId: feedId, replaceInDb: false)
                feedItemInfos = try await feedsDatabase.feedItemInfos(feedId: feedId, pageSize: pageSize, lastPageIdx: lastPageIdx)
                if #available(iOS 14, *) { Logger.feed.trace("Got \(feedItemInfos.count) feedItemsInfos from DB") }
            }

            let feedItemInfoIds = feedItemInfos.map { $0.itemId }
            let missingFeedItems = try await feedItemsDatabase.getMissingFeedItems(infos: feedItemInfos)
            if !missingFeedItems.isEmpty {
                if #available(iOS 14, *) { Logger.feed.trace("Missing \(missingFeedItems.count) feedItems, fetching them") }
                let batchResponse = try await remoteClient.octoService.getBatch(
                    ids: missingFeedItems,
                    options: getOptions,
                    incrementViewCount: false,
                    authenticationMethod: authCallProvider.authenticatedIfPossibleMethod())
                let feedItems = batchResponse.responses.compactMap { response -> Item? in
                    guard response.hasOctoObject else { return nil }
                    let aggregate = response.hasAggregate ? response.aggregate : nil
                    let requesterCtx = response.hasRequesterCtx ? response.requesterCtx : nil
                    return mapper(response.octoObject, aggregate, requesterCtx)
                }
                try await feedItemsDatabase.upsert(feedItems: feedItems)
            }
            let feedItems = try await feedItemsDatabase.getFeedItems(ids: currentIds + feedItemInfoIds)
            let feedItemsPublisher = try feedItemsDatabase.feedItemsPublisher(ids: currentIds + feedItemInfoIds)
                .prepend(feedItems).eraseToAnyPublisher()

            // there is no more items if no next item info page and there is no next local item info
            let hasMoreItems: Bool
            if nextPageCursor == nil {
                hasMoreItems = (try? await feedsDatabase.feedItemInfos(
                    feedId: feedId, pageSize: 1, lastPageIdx: lastPageIdx + pageSize).first) != nil
            } else {
                hasMoreItems = true
            }

            if #available(iOS 14, *) { Logger.feed.trace("Got \(feedItemInfoIds.count) feedItems from DB") }
            return Result(hasMoreItems: hasMoreItems, currentPageCursor: nextPageCursor,
                          nextPageCursor: newNextPageCursor, itemsPublisher: feedItemsPublisher)
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

    private func cleanNonUsedFeedItems() async throws {
        let itemIds = try await feedsDatabase.getAllItemIds()
        try await feedItemsDatabase.deleteAll(except: itemIds)
    }
}
