//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import GRPC
import OctopusGrpcModels

final class FeedServiceInterceptor: Com_Octopuscommunity_FeedServiceClientInterceptorFactoryProtocol, @unchecked Sendable {
    private let getUserIdBlock: () -> String?
    private let updateTokenBlock: (String) -> Void

    init(getUserIdBlock: @escaping () -> String?, updateTokenBlock: @escaping (String) -> Void) {
        self.getUserIdBlock = getUserIdBlock
        self.updateTokenBlock = updateTokenBlock
    }

    func makeGetRootFeedsInfoInterceptors() -> [ClientInterceptor<Com_Octopuscommunity_GetRootFeedsInfoRequest, Com_Octopuscommunity_GetRootFeedsInfoResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeInitializeFeedWithOctoObjectInterceptors() -> [ClientInterceptor<Com_Octopuscommunity_InitializeFeedWithOctoObjectRequest, Com_Octopuscommunity_GetFeedWithOctoObjectPageResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeGetFeedWithOctoObjectPageInterceptors() -> [ClientInterceptor<Com_Octopuscommunity_GetFeedWithOctoObjectPageRequest, Com_Octopuscommunity_GetFeedWithOctoObjectPageResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeInitializeFeedInterceptors() -> [ClientInterceptor<Com_Octopuscommunity_InitializeFeedRequest, Com_Octopuscommunity_GetFeedPageResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeGetFeedPageInterceptors() -> [ClientInterceptor<Com_Octopuscommunity_GetFeedPageRequest, Com_Octopuscommunity_GetFeedPageResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }
}
