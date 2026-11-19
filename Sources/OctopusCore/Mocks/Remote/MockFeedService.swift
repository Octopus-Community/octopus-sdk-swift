//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusRemoteClient
import OctopusGrpcModels

class MockFeedService: FeedService {
    /// Fifo of the responses to `getRootFeedsInfo`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var getRootFeedsInfoResponses = [Result<Com_Octopuscommunity_GetRootFeedsInfoResponse, RemoteClientError>]()
    private(set) var getRootFeedsInfoCallCount = 0
    /// Fifo of the responses to `initializeFeed`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var initializeFeedResponses = [Com_Octopuscommunity_GetFeedPageResponse]()
    // Fifo of the responses to `getNextFeedPage`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var getNextFeedPageResponses = [Com_Octopuscommunity_GetFeedPageResponse]()
    /// Fifo of the responses to `initializeFeedWithOctoObject`.
    private var initializeFeedWithOctoObjectResponses = [Com_Octopuscommunity_GetFeedWithOctoObjectPageResponse]()
    /// Fifo of the responses to `getFeedWithOctoObjectPage`.
    private var getFeedWithOctoObjectPageResponses = [Com_Octopuscommunity_GetFeedWithOctoObjectPageResponse]()
    /// The feed ids passed to `initializeFeed`, in call order.
    private(set) var initializeFeedFeedIds = [String]()
    /// The anchor item ids passed to `initializeFeed`, in call order.
    private(set) var initializeFeedAnchorItemIds = [String?]()
    /// The page sizes passed to `initializeFeed`, in call order.
    private(set) var initializeFeedPageSizes = [Int32]()
    /// The page cursors passed to `getNextFeedPage`, in call order.
    private(set) var getNextFeedPageCursors = [String]()

    init() { }

    func getRootFeedsInfo(authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> OctopusGrpcModels.Com_Octopuscommunity_GetRootFeedsInfoResponse {
        getRootFeedsInfoCallCount += 1
        guard let response = getRootFeedsInfoResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextGetHomePageFeedsInfo must be called before"))
        }
        return try response.get()
    }

    func initializeFeed(feedId: String, pageSize: Int32, anchorItemId: String?,
                        authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError)
    -> OctopusGrpcModels.Com_Octopuscommunity_GetFeedPageResponse {
        initializeFeedFeedIds.append(feedId)
        initializeFeedAnchorItemIds.append(anchorItemId)
        initializeFeedPageSizes.append(pageSize)
        guard let response = initializeFeedResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextInitializeFeed must be called before"))
        }
        return response
    }

    func getNextFeedPage(pageCursor: String, pageSize: Int32, authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError)
    -> OctopusGrpcModels.Com_Octopuscommunity_GetFeedPageResponse {
        getNextFeedPageCursors.append(pageCursor)
        guard let response = getNextFeedPageResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextGetNextFeedPage must be called before"))
        }
        return response
    }

    func initializeFeedWithOctoObject(feedId: String, pageSize: Int32, authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError) -> OctopusGrpcModels.Com_Octopuscommunity_GetFeedWithOctoObjectPageResponse {
        guard let response = initializeFeedWithOctoObjectResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextInitializeFeedWithOctoObject must be called before"))
        }
        return response
    }

    func getFeedWithOctoObjectPage(pageCursor: String, pageSize: Int32, fetchAggregates: Bool,
                                   authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError) -> OctopusGrpcModels.Com_Octopuscommunity_GetFeedWithOctoObjectPageResponse {
        guard let response = getFeedWithOctoObjectPageResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextGetFeedWithOctoObjectPage must be called before"))
        }
        return response
    }
}

extension MockFeedService {
    func injectNextGetRootFeedsInfo(_ response: Com_Octopuscommunity_GetRootFeedsInfoResponse) {
        getRootFeedsInfoResponses.insert(.success(response), at: 0)
    }

    func injectNextGetRootFeedsInfoError(_ error: RemoteClientError) {
        getRootFeedsInfoResponses.insert(.failure(error), at: 0)
    }

    func injectNextInitializeFeed(_ response: Com_Octopuscommunity_GetFeedPageResponse) {
        initializeFeedResponses.insert(response, at: 0)
    }

    func injectNextGetNextFeedPage(_ response: Com_Octopuscommunity_GetFeedPageResponse) {
        getNextFeedPageResponses.insert(response, at: 0)
    }

    func injectNextInitializeFeedWithOctoObject(_ response: Com_Octopuscommunity_GetFeedWithOctoObjectPageResponse) {
        initializeFeedWithOctoObjectResponses.insert(response, at: 0)
    }

    func injectNextGetFeedWithOctoObjectPage(_ response: Com_Octopuscommunity_GetFeedWithOctoObjectPageResponse) {
        getFeedWithOctoObjectPageResponses.insert(response, at: 0)
    }
}
