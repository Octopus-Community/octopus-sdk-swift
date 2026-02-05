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
import SwiftProtobuf
import Logging

public struct OctoObjectInfo {
    public let id: String
    public let hasVideo: Bool

    public init(id: String, hasVideo: Bool) {
        self.id = id
        self.hasVideo = hasVideo
    }
}

public protocol OctoService {
    func get(octoObjectInfo: OctoObjectInfo, options: GetOptions, incrementViewCount: Bool,
             authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetResponse

    func getBatch(octoObjectInfos: [OctoObjectInfo], options: GetOptions, incrementViewCount: Bool,
                  authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetBatchResponse

    func getTopics(authenticationMethod: AuthenticationMethod) async throws(RemoteClientError) -> Com_Octopuscommunity_GetTopicsResponse

    func put(post: Com_Octopuscommunity_RwOctoObject,
             authenticationMethod: AuthenticationMethod) async throws(RemoteClientError) -> Com_Octopuscommunity_PutPostResponse

    func put(comment: Com_Octopuscommunity_RwOctoObject,
             parentIsTranslated: Bool,
             authenticationMethod: AuthenticationMethod) async throws(RemoteClientError) -> Com_Octopuscommunity_PutCommentResponse

    func put(reply: Com_Octopuscommunity_RwOctoObject,
             parentIsTranslated: Bool,
             authenticationMethod: AuthenticationMethod) async throws(RemoteClientError) -> Com_Octopuscommunity_PutReplyResponse

    func react(reactionKind: String,
               objectId: String,
               parentIsTranslated: Bool,
               authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError) -> Com_Octopuscommunity_PutReactionResponse

    func deleteReaction(reactionId: String, authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError) -> Com_Octopuscommunity_DeleteReactionResponse

    func voteOnPoll(objectId: String, answerId: String, parentIsTranslated: Bool, authenticationMethod: AuthenticationMethod)
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

    func getOrCreateBridgePost(post: Com_Octopuscommunity_Post, topicId: String?, clientToken: String?,
                               authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetOrCreateBridgePostResponse

}

class OctoServiceClient: ServiceClient, OctoService {
    
    private let client: Com_Octopuscommunity_OctoObjectServiceAsyncClient

    init(unaryChannel: GRPCChannel, apiKey: String, sdkVersion: String, installId: String, localeIdentifier: String,
         getUserIdBlock: @escaping () -> String?,
         updateTokenBlock: @escaping (String) -> Void) {
        client = Com_Octopuscommunity_OctoObjectServiceAsyncClient(
            channel: unaryChannel,
            interceptors: OctoServiceInterceptor(
                getUserIdBlock: getUserIdBlock, updateTokenBlock: updateTokenBlock))
        super.init(apiKey: apiKey, sdkVersion: sdkVersion, installId: installId, localeIdentifier: localeIdentifier)
    }

    public func get(octoObjectInfo: OctoObjectInfo, options: GetOptions, incrementViewCount: Bool,
                    authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetResponse {
        let request = Com_Octopuscommunity_GetRequest.with {
            $0.octoObjectID = octoObjectInfo.id
            $0.fetchObject = options.contains(.object)
            $0.fetchAggregate = options.contains(.aggregates)
            $0.fetchRequesterCtx = options.contains(.interactions)
            $0.registerView = incrementViewCount
            $0.hasVideo_p = octoObjectInfo.hasVideo
        }

        return try await callRemote(authenticationMethod) {
            try await client.get(request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }

    func getBatch(octoObjectInfos: [OctoObjectInfo], options: GetOptions, incrementViewCount: Bool,
                  authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetBatchResponse {
        let request = Com_Octopuscommunity_GetBatchRequest.with {
            $0.requests = octoObjectInfos.map { octoObjectInfo in
                Com_Octopuscommunity_GetRequest.with {
                    $0.octoObjectID = octoObjectInfo.id
                    $0.fetchObject = options.contains(.object)
                    $0.fetchAggregate = options.contains(.aggregates)
                    $0.fetchRequesterCtx = options.contains(.interactions)
                    $0.registerView = incrementViewCount
                    $0.hasVideo_p = octoObjectInfo.hasVideo
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
                    parentIsTranslated: Bool,
                    authenticationMethod: AuthenticationMethod) async throws(RemoteClientError) -> Com_Octopuscommunity_PutCommentResponse {
        let request = Com_Octopuscommunity_PutRequest.with {
            $0.octoObject = comment
            $0.translatedContent = parentIsTranslated
        }
        return try await callRemote(authenticationMethod) {
            try await client.putComment(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }

    public func put(reply: Com_Octopuscommunity_RwOctoObject,
                    parentIsTranslated: Bool,
                    authenticationMethod: AuthenticationMethod) async throws(RemoteClientError) -> Com_Octopuscommunity_PutReplyResponse {
        let request = Com_Octopuscommunity_PutRequest.with {
            $0.octoObject = reply
            $0.translatedContent = parentIsTranslated
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

    func react(reactionKind: String, objectId: String, parentIsTranslated: Bool,
               authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError) -> Com_Octopuscommunity_PutReactionResponse {
        let request = Com_Octopuscommunity_PutRequest.with {
            $0.octoObject = .with {
                $0.parentID = objectId
                $0.content = .with {
                    $0.reaction = .with {
                        $0.unicode = reactionKind
                    }
                }
            }
            $0.translatedContent = parentIsTranslated
        }
        return try await callRemote(authenticationMethod) {
            try await client.putReaction(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }

    func deleteReaction(reactionId: String, authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError) -> Com_Octopuscommunity_DeleteReactionResponse {
        let request = Com_Octopuscommunity_DeleteRequest.with {
            $0.octoObjectID = reactionId
        }
        return try await callRemote(authenticationMethod) {
            try await client.deleteReaction(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }

    func voteOnPoll(objectId: String, answerId: String, parentIsTranslated: Bool,
                    authenticationMethod: AuthenticationMethod)
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
            $0.translatedContent = parentIsTranslated
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

    func getOrCreateBridgePost(post: Com_Octopuscommunity_Post, topicId: String?, clientToken: String?,
                               authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetOrCreateBridgePostResponse {
        let request = Com_Octopuscommunity_GetOrCreateBridgePostRequest.with {
            $0.postBridge = post
            if let topicId {
                $0.topicID = topicId
            }
            if let clientToken {
                $0.clientToken = clientToken
            }
        }
        return try await callRemote(authenticationMethod) {
            try await client.getOrCreateBridgePost(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }
}
