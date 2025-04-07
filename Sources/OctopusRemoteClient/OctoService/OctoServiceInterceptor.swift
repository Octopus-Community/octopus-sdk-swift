//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import GRPC
import OctopusGrpcModels

final class OctoServiceInterceptor: Com_Octopuscommunity_OctoObjectServiceClientInterceptorFactoryProtocol, @unchecked Sendable {
    private let updateTokenBlock: (String) -> Void

    init(updateTokenBlock: @escaping (String) -> Void) {
        self.updateTokenBlock = updateTokenBlock
    }

    func makePutLikeInterceptors() -> [ClientInterceptor<Com_Octopuscommunity_PutRequest, Com_Octopuscommunity_PutLikeResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeDeleteLikeInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_DeleteLikeRequest, OctopusGrpcModels.Com_Octopuscommunity_DeleteLikeResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeGetInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_GetRequest, OctopusGrpcModels.Com_Octopuscommunity_GetResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeGetBatchInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_GetBatchRequest, OctopusGrpcModels.Com_Octopuscommunity_GetBatchResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makePutCommentInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_PutRequest, OctopusGrpcModels.Com_Octopuscommunity_PutCommentResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeDeleteCommentInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_DeleteCommentRequest, OctopusGrpcModels.Com_Octopuscommunity_DeleteCommentResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeModerateCommentInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_ModerateCommentRequest, OctopusGrpcModels.Com_Octopuscommunity_ModerateCommentResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makePutPostInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_PutRequest, OctopusGrpcModels.Com_Octopuscommunity_PutPostResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeGetTopicsInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_GetTopicsRequest, OctopusGrpcModels.Com_Octopuscommunity_GetTopicsResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeUpdatePostInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_UpdatePostRequest, OctopusGrpcModels.Com_Octopuscommunity_UpdatePostResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeDeletePostInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_DeletePostRequest, OctopusGrpcModels.Com_Octopuscommunity_DeletePostResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeModeratePostInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_ModeratePostRequest, OctopusGrpcModels.Com_Octopuscommunity_ModeratePostResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeReportContentInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_ReportContentRequest, OctopusGrpcModels.Com_Octopuscommunity_ReportContentResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makePutPollVoteInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_PutRequest, OctopusGrpcModels.Com_Octopuscommunity_PutPollVoteResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makePutReplyInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_PutRequest, OctopusGrpcModels.Com_Octopuscommunity_PutReplyResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeDeleteReplyInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_DeleteReplyRequest, OctopusGrpcModels.Com_Octopuscommunity_DeleteReplyResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeModerateReplyInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_ModerateReplyRequest, OctopusGrpcModels.Com_Octopuscommunity_ModerateReplyResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }
}
