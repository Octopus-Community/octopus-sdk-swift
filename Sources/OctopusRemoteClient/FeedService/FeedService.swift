//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
#if canImport(GRPC)
import GRPC
#else
import GRPCSwift
#endif
import OctopusGrpcModels
import Logging

public protocol FeedService {
    func getRootFeedsInfo(authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetRootFeedsInfoResponse

    func initializeFeed(feedId: String, pageSize: Int32, authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetFeedPageResponse

    func getNextFeedPage(pageCursor: String, pageSize: Int32, authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetFeedPageResponse

    /// Initializes a feed and returns the first page with the octo objects already hydrated **and** their
    /// parents in `relatedObjects` / `relatedAggregates` (used by the profile comments feed, which needs
    /// the parent post/comment context that the id-only `initializeFeed` does not provide).
    func initializeFeedWithOctoObject(feedId: String, pageSize: Int32, authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetFeedWithOctoObjectPageResponse

    func getFeedWithOctoObjectPage(pageCursor: String, pageSize: Int32, fetchAggregates: Bool,
                                   authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetFeedWithOctoObjectPageResponse
}

class FeedServiceClient: ServiceClient, FeedService {
    private let client: Com_Octopuscommunity_FeedServiceAsyncClient

    init(unaryChannel: GRPCChannel, apiKey: String, sdkVersion: String, installId: String, localeIdentifier: String,
         getUserIdBlock: @escaping () -> String?,
         updateTokenBlock: @escaping (String) -> Void) {
        client = Com_Octopuscommunity_FeedServiceAsyncClient(
            channel: unaryChannel, interceptors: FeedServiceInterceptor(
                getUserIdBlock: getUserIdBlock, updateTokenBlock: updateTokenBlock))
        super.init(apiKey: apiKey, sdkVersion: sdkVersion, installId: installId, localeIdentifier: localeIdentifier)
    }

    func getRootFeedsInfo(authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> OctopusGrpcModels.Com_Octopuscommunity_GetRootFeedsInfoResponse {
        let request = Com_Octopuscommunity_GetRootFeedsInfoRequest()

        return try await callRemote(authenticationMethod) {
            try await client.getRootFeedsInfo(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }

    func initializeFeed(feedId: String, pageSize: Int32, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> OctopusGrpcModels.Com_Octopuscommunity_GetFeedPageResponse {
        let request = Com_Octopuscommunity_InitializeFeedRequest.with {
            $0.feedID = feedId
            $0.pageSize = pageSize
        }

        return try await callRemote(authenticationMethod) {
            try await client.initializeFeed(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }

    func getNextFeedPage(pageCursor: String, pageSize: Int32, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> OctopusGrpcModels.Com_Octopuscommunity_GetFeedPageResponse {
        let request = Com_Octopuscommunity_GetFeedPageRequest.with {
            $0.pageCursor = pageCursor
            $0.pageSize = pageSize
        }

        return try await callRemote(authenticationMethod) {
            try await client.getFeedPage(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }

    func initializeFeedWithOctoObject(feedId: String, pageSize: Int32, authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError) -> OctopusGrpcModels.Com_Octopuscommunity_GetFeedWithOctoObjectPageResponse {
        let request = Com_Octopuscommunity_InitializeFeedWithOctoObjectRequest.with {
            $0.feedID = feedId
            $0.pageSize = pageSize
        }

        return try await callRemote(authenticationMethod) {
            try await client.initializeFeedWithOctoObject(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }

    func getFeedWithOctoObjectPage(pageCursor: String, pageSize: Int32, fetchAggregates: Bool,
                                   authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError) -> OctopusGrpcModels.Com_Octopuscommunity_GetFeedWithOctoObjectPageResponse {
        let request = Com_Octopuscommunity_GetFeedWithOctoObjectPageRequest.with {
            $0.pageCursor = pageCursor
            $0.pageSize = pageSize
            $0.fetchAggregates = fetchAggregates
        }

        return try await callRemote(authenticationMethod) {
            try await client.getFeedWithOctoObjectPage(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }
}
