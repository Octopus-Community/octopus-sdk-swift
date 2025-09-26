//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusDependencyInjection
import OctopusRemoteClient
import OctopusGrpcModels
import Combine

public struct RootFeed: Equatable, Hashable {
    public let label: String
    public let feedId: String
    public let feed: Feed<Post, Comment>

    init(label: String, feedId: String, postFeedsStore: PostFeedsStore) {
        self.label = label
        self.feedId = feedId
        feed = postFeedsStore.getOrCreate(feedId: feedId)
    }

    public static func == (lhs: RootFeed, rhs: RootFeed) -> Bool {
        lhs.label == rhs.label && lhs.feedId == rhs.feedId
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(label)
        hasher.combine(feedId)
    }
}

struct StorableRootFeed: Equatable {
    public let label: String
    public let feedId: String
}

extension Injected {
    static let rootFeedsRepository = Injector.InjectedIdentifier<RootFeedsRepository>()
}

public class RootFeedsRepository: InjectableObject, @unchecked Sendable {
    public static let injectedIdentifier = Injected.rootFeedsRepository

    private let rootFeedsDatabase: RootFeedsDatabase
    private let authCallProvider: AuthenticatedCallProvider
    private let remoteClient: OctopusRemoteClient
    private let postFeedsStore: PostFeedsStore

    init(injector: Injector) {
        rootFeedsDatabase = injector.getInjected(identifiedBy: Injected.rootFeedsDatabase)
        authCallProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        postFeedsStore = injector.getInjected(identifiedBy: Injected.postFeedsStore)
    }

    public func getRootFeeds() -> AnyPublisher<[RootFeed], Error> {
        return rootFeedsDatabase.rootFeedsPublisher()
            .map { [weak self] rootFeeds in
                guard let self else { return [] }
                return rootFeeds.map {
                    RootFeed(label: $0.label, feedId: $0.feedId, postFeedsStore: self.postFeedsStore)
                }
            }
            .eraseToAnyPublisher()
    }

    public func fetchRootFeeds() async throws(ServerCallError) {
        do {
            let response = try await remoteClient.feedService.getRootFeedsInfo(
                authenticationMethod: authCallProvider.authenticatedIfPossibleMethod())
            let rootFeeds = response.feedsInfo.map { StorableRootFeed(from: $0) }
            try await rootFeedsDatabase.replaceAll(rootFeeds: rootFeeds)
        } catch {
            if let error = error as? RemoteClientError {
                throw .serverError(ServerError(remoteClientError: error))
            } else {
                throw .other(error)
            }
        }
    }
}

// TODO: move it in a TopicTransformation file
extension StorableRootFeed {
    init(from entity: RootFeedEntity) {
        label = entity.label
        feedId = entity.uuid
    }

    init(from serverRootFeed: Com_Octopuscommunity_FeedInfo) {
        feedId = serverRootFeed.id
        label = serverRootFeed.label
    }
}
