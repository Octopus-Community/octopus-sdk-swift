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
    /// Fifo of the responses to `delete(post:)`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var deletePostResponses = [Com_Octopuscommunity_DeletePostResponse]()
    /// Fifo of the responses to `delete(comment:)`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var deleteCommentResponses = [Com_Octopuscommunity_DeleteCommentResponse]()
    /// Fifo of the responses to `like(:)`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var putLikeResponses = [Com_Octopuscommunity_PutLikeResponse]()
    /// Fifo of the responses to `unlike(:)`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var deleteLikeResponses = [Com_Octopuscommunity_DeleteLikeResponse]()
    /// Fifo of the responses to `reportContent(:)`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var reportContentResponses = [Com_Octopuscommunity_ReportContentResponse]()

    init() { }

    func get(octoObjectId: String, options: GetOptions, incrementViewCount: Bool,
             authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError)
    -> OctopusGrpcModels.Com_Octopuscommunity_GetResponse {
        guard let response = getResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextGetResponse must be called before"))
        }
        return response
    }

    func getBatch(ids: [String], options: GetOptions, incrementViewCount: Bool,
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

    func put(comment: Com_Octopuscommunity_RwOctoObject, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError) -> Com_Octopuscommunity_PutCommentResponse {
        guard let response = putCommentResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextPutPostResponse must be called before"))
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

    func like(objectId: String, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> OctopusGrpcModels.Com_Octopuscommunity_PutLikeResponse {
        guard let response = putLikeResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextLikeResponse must be called before"))
        }
        return response
    }

    func unlike(likeId: String, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> OctopusGrpcModels.Com_Octopuscommunity_DeleteLikeResponse {
        guard let response = deleteLikeResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextUnlikeResponse must be called before"))
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

    func injectNextDeletePostResponse(_ response: Com_Octopuscommunity_DeletePostResponse) {
        deletePostResponses.insert(response, at: 0)
    }

    func injectNextDeleteCommentResponse(_ response: Com_Octopuscommunity_DeleteCommentResponse) {
        deleteCommentResponses.insert(response, at: 0)
    }

    func injectNextLikeResponse(_ response: Com_Octopuscommunity_PutLikeResponse) {
        putLikeResponses.insert(response, at: 0)
    }

    func injectNextUnlikeResponse(_ response: Com_Octopuscommunity_DeleteLikeResponse) {
        deleteLikeResponses.insert(response, at: 0)
    }

    func injectNextReportContentResponse(_ response: Com_Octopuscommunity_ReportContentResponse) {
        reportContentResponses.insert(response, at: 0)
    }
}
