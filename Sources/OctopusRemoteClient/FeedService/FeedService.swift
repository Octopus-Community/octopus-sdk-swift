//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import GRPC
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
}

class FeedServiceClient: ServiceClient, FeedService {
    private let client: Com_Octopuscommunity_FeedServiceAsyncClient


    init(unaryChannel: GRPCChannel, apiKey: String, sdkVersion: String, installId: String,
         getUserIdBlock: @escaping () -> String?,
         updateTokenBlock: @escaping (String) -> Void) {
        client = Com_Octopuscommunity_FeedServiceAsyncClient(
            channel: unaryChannel, interceptors: FeedServiceInterceptor(
                getUserIdBlock: getUserIdBlock, updateTokenBlock: updateTokenBlock))
        super.init(apiKey: apiKey, sdkVersion: sdkVersion, installId: installId)
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
}
