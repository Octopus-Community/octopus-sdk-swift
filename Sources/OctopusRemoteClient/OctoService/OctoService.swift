//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import GRPC
import OctopusGrpcModels
import SwiftProtobuf
import Logging

public protocol OctoService {
    func get(octoObjectId: String, options: GetOptions, incrementViewCount: Bool,
             authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetResponse

    func getBatch(ids: [String], options: GetOptions, incrementViewCount: Bool,
                  authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetBatchResponse

    func getTopics(authenticationMethod: AuthenticationMethod) async throws(RemoteClientError) -> Com_Octopuscommunity_GetTopicsResponse

    func put(post: Com_Octopuscommunity_RwOctoObject,
             authenticationMethod: AuthenticationMethod) async throws(RemoteClientError) -> Com_Octopuscommunity_PutPostResponse

    func put(comment: Com_Octopuscommunity_RwOctoObject,
             authenticationMethod: AuthenticationMethod) async throws(RemoteClientError) -> Com_Octopuscommunity_PutCommentResponse

    func put(reply: Com_Octopuscommunity_RwOctoObject,
             authenticationMethod: AuthenticationMethod) async throws(RemoteClientError) -> Com_Octopuscommunity_PutReplyResponse

    func like(objectId: String, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError) -> Com_Octopuscommunity_PutLikeResponse

    func unlike(likeId: String, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError) -> Com_Octopuscommunity_DeleteLikeResponse

    func voteOnPoll(objectId: String, answerId: String, authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError) -> Com_Octopuscommunity_PutPollVoteResponse

    func delete(post postId: String, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_DeletePostResponse

    func delete(comment commentId: String, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_DeleteCommentResponse

    func delete(reply replyId: String, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_DeleteReplyResponse

    func reportContent(objectId: String, reasons: [Com_Octopuscommunity_ReportReasonCode],
                       authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_ReportContentResponse

}

class OctoServiceClient: ServiceClient, OctoService {
    
    private let client: Com_Octopuscommunity_OctoObjectServiceAsyncClient

    init(unaryChannel: GRPCChannel, apiKey: String, sdkVersion: String, updateTokenBlock: @escaping (String) -> Void) {
        client = Com_Octopuscommunity_OctoObjectServiceAsyncClient(
            channel: unaryChannel,
            interceptors: OctoServiceInterceptor(updateTokenBlock: updateTokenBlock))
        super.init(apiKey: apiKey, sdkVersion: sdkVersion)
    }

    public func get(octoObjectId: String, options: GetOptions, incrementViewCount: Bool,
                    authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetResponse {
        let request = Com_Octopuscommunity_GetRequest.with {
            $0.octoObjectID = octoObjectId
            $0.fetchObject = options.contains(.object)
            $0.fetchAggregate = options.contains(.aggregates)
            $0.fetchRequesterCtx = options.contains(.interactions)
            $0.registerView = incrementViewCount
        }

        return try await callRemote(authenticationMethod) {
            try await client.get(request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }

    func getBatch(ids: [String], options: GetOptions, incrementViewCount: Bool,
                  authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetBatchResponse {
        let request = Com_Octopuscommunity_GetBatchRequest.with {
            $0.requests = ids.map { id in
                Com_Octopuscommunity_GetRequest.with {
                    $0.octoObjectID = id
                    $0.fetchObject = options.contains(.object)
                    $0.fetchAggregate = options.contains(.aggregates)
                    $0.fetchRequesterCtx = options.contains(.interactions)
                    $0.registerView = incrementViewCount
                }
            }
        }

        return try await callRemote(authenticationMethod) {
            try await client.getBatch(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }

    public func getTopics(authenticationMethod: AuthenticationMethod) async throws(RemoteClientError) -> Com_Octopuscommunity_GetTopicsResponse {
        let request = Com_Octopuscommunity_GetTopicsRequest()

        return try await callRemote(authenticationMethod) {
            try await client.getTopics(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }

    public func put(post: Com_Octopuscommunity_RwOctoObject,
                    authenticationMethod: AuthenticationMethod) async throws(RemoteClientError) -> Com_Octopuscommunity_PutPostResponse {
        let request = Com_Octopuscommunity_PutRequest.with {
            $0.octoObject = post
        }
        return try await callRemote(authenticationMethod) {
            try await client.putPost(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }

    public func put(comment: Com_Octopuscommunity_RwOctoObject,
                    authenticationMethod: AuthenticationMethod) async throws(RemoteClientError) -> Com_Octopuscommunity_PutCommentResponse {
        let request = Com_Octopuscommunity_PutRequest.with {
            $0.octoObject = comment
        }
        return try await callRemote(authenticationMethod) {
            try await client.putComment(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }

    public func put(reply: Com_Octopuscommunity_RwOctoObject,
                    authenticationMethod: AuthenticationMethod) async throws(RemoteClientError) -> Com_Octopuscommunity_PutReplyResponse {
        let request = Com_Octopuscommunity_PutRequest.with {
            $0.octoObject = reply
        }
        return try await callRemote(authenticationMethod) {
            try await client.putReply(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }

    func delete(post postId: String, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_DeletePostResponse {
        let request = Com_Octopuscommunity_DeletePostRequest.with {
            $0.octoObjectID = postId
        }
        return try await callRemote(authenticationMethod) {
            try await client.deletePost(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }

    func delete(comment commentId: String, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_DeleteCommentResponse {
        let request = Com_Octopuscommunity_DeleteCommentRequest.with {
            $0.octoObjectID = commentId
        }
        return try await callRemote(authenticationMethod) {
            try await client.deleteComment(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }

    func delete(reply replyId: String, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_DeleteReplyResponse {
        let request = Com_Octopuscommunity_DeleteReplyRequest.with {
            $0.octoObjectID = replyId
        }
        return try await callRemote(authenticationMethod) {
            try await client.deleteReply(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }

    func like(objectId: String, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_PutLikeResponse {
        let request = Com_Octopuscommunity_PutRequest.with {
            $0.octoObject = .with {
                $0.parentID = objectId
                $0.content = .with {
                    $0.like = Com_Octopuscommunity_Like()
                }
            }
        }
        return try await callRemote(authenticationMethod) {
            try await client.putLike(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }

    func unlike(likeId: String, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_DeleteLikeResponse {
        let request = Com_Octopuscommunity_DeleteLikeRequest.with {
            $0.octoObjectID = likeId
        }
        return try await callRemote(authenticationMethod) {
            try await client.deleteLike(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }

    func voteOnPoll(objectId: String, answerId: String, authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError) -> Com_Octopuscommunity_PutPollVoteResponse {
        let request = Com_Octopuscommunity_PutRequest.with {
            $0.octoObject = .with {
                $0.parentID = objectId
                $0.content = .with {
                    $0.vote = .with {
                        $0.pollAnswerID = answerId
                    }
                }
            }
        }
        return try await callRemote(authenticationMethod) {
            try await client.putPollVote(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }

    func reportContent(objectId: String, reasons: [Com_Octopuscommunity_ReportReasonCode],
                       authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_ReportContentResponse {
        let request = Com_Octopuscommunity_ReportContentRequest.with {
            $0.octoObjectID = objectId
            $0.reasonCodes = reasons
        }
        return try await callRemote(authenticationMethod) {
            try await client.reportContent(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }
}
