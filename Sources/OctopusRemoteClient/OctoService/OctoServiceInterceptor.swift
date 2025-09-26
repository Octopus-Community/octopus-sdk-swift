//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import GRPC
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

    func makeDeleteLikeInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_DeleteLikeRequest, OctopusGrpcModels.Com_Octopuscommunity_DeleteLikeResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeGetInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_GetRequest, OctopusGrpcModels.Com_Octopuscommunity_GetResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeGetBatchInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_GetBatchRequest, OctopusGrpcModels.Com_Octopuscommunity_GetBatchResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makePutCommentInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_PutRequest, OctopusGrpcModels.Com_Octopuscommunity_PutCommentResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeDeleteCommentInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_DeleteCommentRequest, OctopusGrpcModels.Com_Octopuscommunity_DeleteCommentResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeModerateCommentInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_ModerateCommentRequest, OctopusGrpcModels.Com_Octopuscommunity_ModerateCommentResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makePutPostInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_PutRequest, OctopusGrpcModels.Com_Octopuscommunity_PutPostResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeGetTopicsInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_GetTopicsRequest, OctopusGrpcModels.Com_Octopuscommunity_GetTopicsResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeUpdatePostInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_UpdatePostRequest, OctopusGrpcModels.Com_Octopuscommunity_UpdatePostResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeDeletePostInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_DeletePostRequest, OctopusGrpcModels.Com_Octopuscommunity_DeletePostResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeModeratePostInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_ModeratePostRequest, OctopusGrpcModels.Com_Octopuscommunity_ModeratePostResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeReportContentInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_ReportContentRequest, OctopusGrpcModels.Com_Octopuscommunity_ReportContentResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makePutPollVoteInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_PutRequest, OctopusGrpcModels.Com_Octopuscommunity_PutPollVoteResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makePutReplyInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_PutRequest, OctopusGrpcModels.Com_Octopuscommunity_PutReplyResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeDeleteReplyInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_DeleteReplyRequest, OctopusGrpcModels.Com_Octopuscommunity_DeleteReplyResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeModerateReplyInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_ModerateReplyRequest, OctopusGrpcModels.Com_Octopuscommunity_ModerateReplyResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeGetOrCreateBridgePostInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_GetOrCreateBridgePostRequest, OctopusGrpcModels.Com_Octopuscommunity_GetOrCreateBridgePostResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makePutReactionInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_PutRequest, OctopusGrpcModels.Com_Octopuscommunity_PutReactionResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeDeleteReactionInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_DeleteRequest, OctopusGrpcModels.Com_Octopuscommunity_DeleteReactionResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeShadowbanPostInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_ShadowbanPostRequest, OctopusGrpcModels.Com_Octopuscommunity_ShadowbanPostResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeShadowbanCommentInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_ShadowbanCommentRequest, OctopusGrpcModels.Com_Octopuscommunity_ShadowbanCommentResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeShadowbanReplyInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_ShadowbanReplyRequest, OctopusGrpcModels.Com_Octopuscommunity_ShadowbanReplyResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeUnshadowbanPostInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_UnshadowbanPostRequest, OctopusGrpcModels.Com_Octopuscommunity_UnshadowbanPostResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeUnshadowbanCommentInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_UnshadowbanCommentRequest, OctopusGrpcModels.Com_Octopuscommunity_UnshadowbanCommentResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeUnshadowbanReplyInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_UnshadowbanReplyRequest, OctopusGrpcModels.Com_Octopuscommunity_UnshadowbanReplyResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }
}
