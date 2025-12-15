//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
#if canImport(GRPC)
import GRPC
#else
import GRPCSwift
#endif
import OctopusGrpcModels

final class OctoServiceInterceptor: Com_Octopuscommunity_OctoObjectServiceClientInterceptorFactoryProtocol, @unchecked Sendable {
    private let getUserIdBlock: () -> String?
    private let updateTokenBlock: (String) -> Void

    init(getUserIdBlock: @escaping () -> String?, updateTokenBlock: @escaping (String) -> Void) {
        self.getUserIdBlock = getUserIdBlock
        self.updateTokenBlock = updateTokenBlock
    }

    func makePutLikeInterceptors() -> [ClientInterceptor<Com_Octopuscommunity_PutRequest, Com_Octopuscommunity_PutLikeResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeDeleteLikeInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_DeleteLikeRequest, OctopusGrpcModels.Com_Octopuscommunity_DeleteLikeResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeGetInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_GetRequest, OctopusGrpcModels.Com_Octopuscommunity_GetResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeGetBatchInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_GetBatchRequest, OctopusGrpcModels.Com_Octopuscommunity_GetBatchResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makePutCommentInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_PutRequest, OctopusGrpcModels.Com_Octopuscommunity_PutCommentResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeDeleteCommentInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_DeleteCommentRequest, OctopusGrpcModels.Com_Octopuscommunity_DeleteCommentResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeModerateCommentInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_ModerateCommentRequest, OctopusGrpcModels.Com_Octopuscommunity_ModerateCommentResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makePutPostInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_PutRequest, OctopusGrpcModels.Com_Octopuscommunity_PutPostResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeGetTopicsInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_GetTopicsRequest, OctopusGrpcModels.Com_Octopuscommunity_GetTopicsResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeUpdatePostInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_UpdatePostRequest, OctopusGrpcModels.Com_Octopuscommunity_UpdatePostResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeDeletePostInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_DeletePostRequest, OctopusGrpcModels.Com_Octopuscommunity_DeletePostResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeModeratePostInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_ModeratePostRequest, OctopusGrpcModels.Com_Octopuscommunity_ModeratePostResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeReportContentInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_ReportContentRequest, OctopusGrpcModels.Com_Octopuscommunity_ReportContentResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makePutPollVoteInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_PutRequest, OctopusGrpcModels.Com_Octopuscommunity_PutPollVoteResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makePutReplyInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_PutRequest, OctopusGrpcModels.Com_Octopuscommunity_PutReplyResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeDeleteReplyInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_DeleteReplyRequest, OctopusGrpcModels.Com_Octopuscommunity_DeleteReplyResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeModerateReplyInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_ModerateReplyRequest, OctopusGrpcModels.Com_Octopuscommunity_ModerateReplyResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeGetOrCreateBridgePostInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_GetOrCreateBridgePostRequest, OctopusGrpcModels.Com_Octopuscommunity_GetOrCreateBridgePostResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makePutReactionInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_PutRequest, OctopusGrpcModels.Com_Octopuscommunity_PutReactionResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeDeleteReactionInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_DeleteRequest, OctopusGrpcModels.Com_Octopuscommunity_DeleteReactionResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeShadowbanPostInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_ShadowbanPostRequest, OctopusGrpcModels.Com_Octopuscommunity_ShadowbanPostResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeShadowbanCommentInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_ShadowbanCommentRequest, OctopusGrpcModels.Com_Octopuscommunity_ShadowbanCommentResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeShadowbanReplyInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_ShadowbanReplyRequest, OctopusGrpcModels.Com_Octopuscommunity_ShadowbanReplyResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeUnshadowbanPostInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_UnshadowbanPostRequest, OctopusGrpcModels.Com_Octopuscommunity_UnshadowbanPostResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeUnshadowbanCommentInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_UnshadowbanCommentRequest, OctopusGrpcModels.Com_Octopuscommunity_UnshadowbanCommentResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeUnshadowbanReplyInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_UnshadowbanReplyRequest, OctopusGrpcModels.Com_Octopuscommunity_UnshadowbanReplyResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }
}
