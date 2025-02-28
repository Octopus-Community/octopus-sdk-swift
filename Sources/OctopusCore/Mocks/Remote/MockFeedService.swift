//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import RemoteClient
import GrpcModels

class MockFeedService: FeedService {
    /// Fifo of the responses to `getRootFeedsInfo`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var getRootFeedsInfoResponses = [Com_Octopuscommunity_GetRootFeedsInfoResponse]()
    /// Fifo of the responses to `initializeFeed`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var initializeFeedResponses = [Com_Octopuscommunity_GetFeedPageResponse]()
    // Fifo of the responses to `getNextFeedPage`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var getNextFeedPageResponses = [Com_Octopuscommunity_GetFeedPageResponse]()

    init() { }

    func getRootFeedsInfo(authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> GrpcModels.Com_Octopuscommunity_GetRootFeedsInfoResponse {
        guard let response = getRootFeedsInfoResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextGetHomePageFeedsInfo must be called before"))
        }
        return response
    }

    func initializeFeed(feedId: String, pageSize: Int32, authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError)
    -> GrpcModels.Com_Octopuscommunity_GetFeedPageResponse {
        guard let response = initializeFeedResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextInitializeFeed must be called before"))
        }
        return response
    }

    func getNextFeedPage(pageCursor: String, pageSize: Int32, authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError)
    -> GrpcModels.Com_Octopuscommunity_GetFeedPageResponse {
        guard let response = getNextFeedPageResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextGetNextFeedPage must be called before"))
        }
        return response
    }
}

extension MockFeedService {
    func injectNextGetRootFeedsInfo(_ response: Com_Octopuscommunity_GetRootFeedsInfoResponse) {
        getRootFeedsInfoResponses.insert(response, at: 0)
    }

    func injectNextInitializeFeed(_ response: Com_Octopuscommunity_GetFeedPageResponse) {
        initializeFeedResponses.insert(response, at: 0)
    }

    func injectNextGetNextFeedPage(_ response: Com_Octopuscommunity_GetFeedPageResponse) {
        getNextFeedPageResponses.insert(response, at: 0)
    }
}
