//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import OctopusRemoteClient
import OctopusGrpcModels
import SwiftProtobuf
import OctopusDependencyInjection
import os

extension Injected {
    static let commentsRepository = Injector.InjectedIdentifier<CommentsRepository>()
}

public class CommentsRepository: InjectableObject, @unchecked Sendable {
    public static let injectedIdentifier = Injected.commentsRepository

    public var commentSentPublisher: AnyPublisher<Comment, Never> {
        _commentSentPublisher.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
    private let _commentSentPublisher = PassthroughSubject<Comment, Never>()

    public var commentDeletedPublisher: AnyPublisher<Comment?, Never> {
        _commentDeletedPublisher.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
    private let _commentDeletedPublisher = PassthroughSubject<Comment?, Never>()

    private let remoteClient: OctopusRemoteClient
    private let authCallProvider: AuthenticatedCallProvider
    private let commentsDatabase: CommentsDatabase
    private let networkMonitor: NetworkMonitor
    private let replyFeedsStore: ReplyFeedsStore
    private let blockedUserIdsProvider: BlockedUserIdsProvider
    private let validator: Validators.Comment
    private let userInteractionsDelegate: UserInteractionsDelegate

    init(injector: Injector) {
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        authCallProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)
        commentsDatabase = injector.getInjected(identifiedBy: Injected.commentsDatabase)
        networkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor)
        replyFeedsStore = injector.getInjected(identifiedBy: Injected.replyFeedsStore)
        blockedUserIdsProvider = injector.getInjected(identifiedBy: Injected.blockedUserIdsProvider)
        validator = injector.getInjected(identifiedBy: Injected.validators).comment
        userInteractionsDelegate = UserInteractionsDelegate(injector: injector)
    }

    public func getComment(uuid: String) -> AnyPublisher<Comment?, Error> {
        return Publishers.CombineLatest(
            commentsDatabase.commentPublisher(uuid: uuid),
            blockedUserIdsProvider.blockedUserIdsPublisher.setFailureType(to: Error.self)
        )
        .map { [unowned self] in
            guard let storableComment = $0 else { return nil }
            guard !storableComment.author.isBlocked(in: $1) else { return nil }
            return Comment(storableComment: storableComment, replyFeedsStore: replyFeedsStore)
        }.eraseToAnyPublisher()
    }

    public func fetchComment(uuid: String, incrementViewCount: Bool = false) async throws(ServerCallError) {
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        do {
            let response = try await remoteClient.octoService.get(
                octoObjectId: uuid,
                options: .all,
                incrementViewCount: incrementViewCount,
                authenticationMethod: authCallProvider.authenticatedIfPossibleMethod())
            let octoComment = response.octoObject
            let aggregate = response.hasAggregate ? response.aggregate : nil
            let userInteraction = response.hasRequesterCtx ? response.requesterCtx : nil
            guard let comment = StorableComment(
                octoComment: octoComment, aggregate: aggregate, userInteraction: userInteraction) else {
                throw InternalError.objectMalformed
            }
            try await commentsDatabase.upsert(comments: [comment])
        } catch {
            if let error = error as? RemoteClientError {
                if case .notFound = error {
                    try? await commentsDatabase.delete(commentId: uuid)
                    _commentDeletedPublisher.send(nil)
                }
                throw .serverError(ServerError(remoteClientError: error))
            } else {
                throw .other(error)
            }
        }
    }

    @discardableResult
    public func send(_ comment: WritableComment) async throws(SendComment.Error) -> (Comment, Data?) {
        guard validator.validate(comment: comment) else {
            throw .serverCall(.other(InternalError.objectMalformed))
        }
        guard networkMonitor.connectionAvailable else { throw .serverCall(.noNetwork) }

        do {
            var comment = comment
            if let imageData = comment.imageData {
                let (resizedImgData, isCompressed) = ImageResizer.resizeIfNeeded(imageData: imageData)
                comment.imageData = resizedImgData
                comment.isImageCompressed = isCompressed
            }
            let response = try await remoteClient.octoService.put(
                comment: comment.rwOctoObject(),
                authenticationMethod: try authCallProvider.authenticatedMethod())

            switch response.result {
            case let .success(content):
                guard let finalComment = StorableComment(octoComment: content.comment, aggregate: nil,
                                                         userInteraction: nil) else {
                    throw SendComment.Error.serverCall(.other(nil))
                }
                try await commentsDatabase.upsert(comments: [finalComment])
                let newComment = Comment(storableComment: finalComment, replyFeedsStore: replyFeedsStore)
                _commentSentPublisher.send(newComment)
                return (newComment, comment.imageData)
            case let .fail(failure):
                throw SendComment.Error.validation(.init(from: failure))
            case .none:
                throw SendComment.Error.serverCall(.other(nil))
            }
        } catch {
            if let error = error as? SendComment.Error {
                throw error
            } else if let error = error as? RemoteClientError {
                throw .serverCall(.serverError(ServerError(remoteClientError: error)))
            } else {
                throw .serverCall(.other(error))
            }
        }
    }

    public func deleteComment(commentId: String) async throws(AuthenticatedActionError) {
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        do {
            _ = try await remoteClient.octoService.delete(
                comment: commentId,
                authenticationMethod: try authCallProvider.authenticatedMethod())

            let comment = try? await commentsDatabase.getComments(ids: [commentId]).first
                .map { Comment(storableComment: $0, replyFeedsStore: replyFeedsStore) }

            try await commentsDatabase.delete(commentId: commentId)
            _commentDeletedPublisher.send(comment)
        } catch {
            if let error = error as? AuthenticatedActionError {
                throw error
            } else if let error = error as? RemoteClientError {
                throw .serverError(ServerError(remoteClientError: error))
            } else {
                throw .other(error)
            }
        }
    }

    public func fetchAdditionalData(ids: [String], incrementViewCount: Bool = false) async throws(ServerCallError) {
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        do {
            if #available(iOS 14, *) { Logger.comments.trace("Fetching additional data for ids: \(ids)") }
            let batchResponse = try await remoteClient.octoService.getBatch(
                ids: ids,
                options: [.aggregates, .interactions],
                incrementViewCount: incrementViewCount,
                authenticationMethod: authCallProvider.authenticatedIfPossibleMethod())
            let additionalData = batchResponse.responses
                .compactMap { response -> (String, AggregatedInfo?, UserInteractions?)? in
                    let aggregateInfo = response.hasAggregate ? AggregatedInfo(from: response.aggregate) : nil
                    let userInteractions = response.hasRequesterCtx ? UserInteractions(from: response.requesterCtx) : nil
                    let id = response.octoObjectID
                    return (id, aggregateInfo, userInteractions)
                }
            try await commentsDatabase.update(additionalData: additionalData)
        } catch {
            if let error = error as? RemoteClientError {
                throw .serverError(ServerError(remoteClientError: error))
            } else {
                throw .other(error)
            }
        }
    }

    public func set(reaction: ReactionKind?, comment: Comment) async throws(Reaction.Error) {
        try await userInteractionsDelegate.set(reaction: reaction, content: comment)
    }
}
