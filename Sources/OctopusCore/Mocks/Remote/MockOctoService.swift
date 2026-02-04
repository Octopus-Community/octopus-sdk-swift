//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusRemoteClient
import OctopusGrpcModels

class MockOctoService: OctoService {
    /// Fifo of the responses to `get(octoObjectId:)`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var getResponses = [Com_Octopuscommunity_GetResponse]()
    /// Fifo of the responses to `getBatch`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var getBatchResponses = [Com_Octopuscommunity_GetBatchResponse]()
    // Fifo of the responses to `getTopics`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var getTopicsResponses = [Com_Octopuscommunity_GetTopicsResponse]()
    /// Fifo of the responses to `put(post:)`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var putPostResponses = [Com_Octopuscommunity_PutPostResponse]()
    /// Fifo of the responses to `put(comment:)`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var putCommentResponses = [Com_Octopuscommunity_PutCommentResponse]()
    /// Fifo of the responses to `put(reply:)`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var putReplyResponses = [Com_Octopuscommunity_PutReplyResponse]()
    /// Fifo of the responses to `delete(post:)`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var deletePostResponses = [Com_Octopuscommunity_DeletePostResponse]()
    /// Fifo of the responses to `delete(comment:)`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var deleteCommentResponses = [Com_Octopuscommunity_DeleteCommentResponse]()
    /// Fifo of the responses to `delete(reply:)`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var deleteReplyResponses = [Com_Octopuscommunity_DeleteReplyResponse]()
    /// Fifo of the responses to `react(:)`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var putReactionResponses = [Com_Octopuscommunity_PutReactionResponse]()
    /// Fifo of the responses to `deleteReaction(:)`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var deleteReactionResponses = [Com_Octopuscommunity_DeleteReactionResponse]()
    /// Fifo of the responses to `voteOnPoll(:)`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var putPollVoteResponses = [Com_Octopuscommunity_PutPollVoteResponse]()
    /// Fifo of the responses to `reportContent(:)`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var reportContentResponses = [Com_Octopuscommunity_ReportContentResponse]()
    /// Fifo of the responses to `getOrCreateBridgePost(:)`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var getOrCreateBridgePostResponse = [Com_Octopuscommunity_GetOrCreateBridgePostResponse]()

    init() { }

    func get(octoObjectInfo: OctoObjectInfo, options: GetOptions, incrementViewCount: Bool,
             authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError)
    -> OctopusGrpcModels.Com_Octopuscommunity_GetResponse {
        guard let response = getResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextGetResponse must be called before"))
        }
        return response
    }

    func getBatch(octoObjectInfos: [OctoObjectInfo], options: GetOptions, incrementViewCount: Bool,
                  authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError)
    -> OctopusGrpcModels.Com_Octopuscommunity_GetBatchResponse {
        guard let response = getBatchResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextGetBatchResponse must be called before"))
        }
        return response
    }

    func getTopics(authenticationMethod: AuthenticationMethod) async throws(RemoteClientError) -> Com_Octopuscommunity_GetTopicsResponse {
        guard let response = getTopicsResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextGetTopicsResponse must be called before"))
        }
        return response
    }

    func put(post: Com_Octopuscommunity_RwOctoObject, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError) -> Com_Octopuscommunity_PutPostResponse {
        guard let response = putPostResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextPutPostResponse must be called before"))
        }
        return response
    }

    func put(comment: Com_Octopuscommunity_RwOctoObject,
             parentIsTranslated: Bool,
             authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_PutCommentResponse {
        guard let response = putCommentResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextPutCommentResponse must be called before"))
        }
        return response
    }

    func put(reply: Com_Octopuscommunity_RwOctoObject,
             parentIsTranslated: Bool,
             authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError)
    -> Com_Octopuscommunity_PutReplyResponse {
        guard let response = putReplyResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextPutReplyResponse must be called before"))
        }
        return response
    }

    func delete(post postId: String, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> OctopusGrpcModels.Com_Octopuscommunity_DeletePostResponse {
        guard let response = deletePostResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextDeletePostResponse must be called before"))
        }
        return response
    }

    func delete(comment commentId: String, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> OctopusGrpcModels.Com_Octopuscommunity_DeleteCommentResponse {
        guard let response = deleteCommentResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextDeleteCommentResponse must be called before"))
        }
        return response
    }

    func delete(reply replyId: String, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> OctopusGrpcModels.Com_Octopuscommunity_DeleteReplyResponse {
        guard let response = deleteReplyResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextDeleteReplyResponse must be called before"))
        }
        return response
    }

    func react(reactionKind: String, objectId: String, parentIsTranslated: Bool, authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError) -> Com_Octopuscommunity_PutReactionResponse {
        guard let response = putReactionResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextReactionResponse must be called before"))
        }
        return response
    }

    func deleteReaction(reactionId: String, authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError) -> Com_Octopuscommunity_DeleteReactionResponse {
        guard let response = deleteReactionResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextDeleteReactionResponse must be called before"))
        }
        return response
    }

    func voteOnPoll(objectId: String, answerId: String, parentIsTranslated: Bool, authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError) -> Com_Octopuscommunity_PutPollVoteResponse {
        guard let response = putPollVoteResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextVoteOnPollResponse must be called before"))
        }
        return response
    }

    func reportContent(objectId: String, reasons: [Com_Octopuscommunity_ReportReasonCode],
                       authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_ReportContentResponse {
        guard let response = reportContentResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextReportContentResponse must be called before"))
        }
        return response
    }

    func getOrCreateBridgePost(post: Com_Octopuscommunity_Post, topicId: String?, clientToken: String?,
                               authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetOrCreateBridgePostResponse {
        guard let response = getOrCreateBridgePostResponse.popLast() else {
            throw .unknown(MockError("Dev error, injectNextGetOrCreateBridgePostResponse must be called before"))
        }
        return response
    }
}

extension MockOctoService {
    func injectNextGetResponse(_ response: Com_Octopuscommunity_GetResponse) {
        getResponses.insert(response, at: 0)
    }

    func injectNextGetBatchResponse(_ response: Com_Octopuscommunity_GetBatchResponse) {
        getBatchResponses.insert(response, at: 0)
    }

    func injectNextGetTopicsResponse(_ response: Com_Octopuscommunity_GetTopicsResponse) {
        getTopicsResponses.insert(response, at: 0)
    }

    func injectNextPutPostResponse(_ response: Com_Octopuscommunity_PutPostResponse) {
        putPostResponses.insert(response, at: 0)
    }

    func injectNextPutCommentResponse(_ response: Com_Octopuscommunity_PutCommentResponse) {
        putCommentResponses.insert(response, at: 0)
    }

    func injectNextPutReplyResponse(_ response: Com_Octopuscommunity_PutReplyResponse) {
        putReplyResponses.insert(response, at: 0)
    }

    func injectNextDeletePostResponse(_ response: Com_Octopuscommunity_DeletePostResponse) {
        deletePostResponses.insert(response, at: 0)
    }

    func injectNextDeleteCommentResponse(_ response: Com_Octopuscommunity_DeleteCommentResponse) {
        deleteCommentResponses.insert(response, at: 0)
    }

    func injectNextDeleteReplyResponse(_ response: Com_Octopuscommunity_DeleteReplyResponse) {
        deleteReplyResponses.insert(response, at: 0)
    }

    func injectNextReactionResponse(_ response: Com_Octopuscommunity_PutReactionResponse) {
        putReactionResponses.insert(response, at: 0)
    }

    func injectNextDeleteReactionResponse(_ response: Com_Octopuscommunity_DeleteReactionResponse) {
        deleteReactionResponses.insert(response, at: 0)
    }

    func injectNextVoteOnPollResponse(_ response: Com_Octopuscommunity_PutPollVoteResponse) {
        putPollVoteResponses.insert(response, at: 0)
    }

    func injectNextReportContentResponse(_ response: Com_Octopuscommunity_ReportContentResponse) {
        reportContentResponses.insert(response, at: 0)
    }

    func injectNextGetOrCreateBridgePostResponse(_ response: Com_Octopuscommunity_GetOrCreateBridgePostResponse) {
        getOrCreateBridgePostResponse.insert(response, at: 0)
    }
}
