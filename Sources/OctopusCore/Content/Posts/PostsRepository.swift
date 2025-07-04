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
    static let postsRepository = Injector.InjectedIdentifier<PostsRepository>()
}

public class PostsRepository: InjectableObject, @unchecked Sendable {
    public static let injectedIdentifier = Injected.postsRepository

    private let remoteClient: OctopusRemoteClient
    private let authCallProvider: AuthenticatedCallProvider
    private let postsDatabase: PostsDatabase
    private let networkMonitor: NetworkMonitor
    private let commentFeedsStore: CommentFeedsStore
    private let blockedUserIdsProvider: BlockedUserIdsProvider
    private let validator: Validators.Post

    public var postSentPublisher: AnyPublisher<Void, Never> {
        _postSentPublisher.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
    private let _postSentPublisher = PassthroughSubject<Void, Never>()

    public var postDeletedPublisher: AnyPublisher<Void, Never> {
        _postDeletedPublisher.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
    private let _postDeletedPublisher = PassthroughSubject<Void, Never>()

    init(injector: Injector) {
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        postsDatabase = injector.getInjected(identifiedBy: Injected.postsDatabase)
        networkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor)
        authCallProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)
        blockedUserIdsProvider = injector.getInjected(identifiedBy: Injected.blockedUserIdsProvider)
        validator = injector.getInjected(identifiedBy: Injected.validators).post

        commentFeedsStore = injector.getInjected(identifiedBy: Injected.commentFeedsStore)
    }

    public func getPost(uuid: String) -> AnyPublisher<Post?, Error> {
        return Publishers.CombineLatest(
            postsDatabase.postPublisher(uuid: uuid),
            blockedUserIdsProvider.blockedUserIdsPublisher.setFailureType(to: Error.self)
        )
        .map { [unowned self] in
            guard let storablePost = $0 else { return nil }
            guard !storablePost.author.isBlocked(in: $1) else { return nil }
            return Post(storablePost: storablePost, commentFeedsStore: commentFeedsStore)
        }.eraseToAnyPublisher()
    }

    public func fetchPost(uuid: String, incrementViewCount: Bool = false) async throws(ServerCallError) {
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        do {
            let response = try await remoteClient.octoService.get(
                octoObjectId: uuid,
                options: .all,
                incrementViewCount: incrementViewCount,
                authenticationMethod: authCallProvider.authenticatedIfPossibleMethod())
            let octoPost = response.octoObject
            let aggregate = response.hasAggregate ? response.aggregate : nil
            let userInteraction = response.hasRequesterCtx ? response.requesterCtx : nil
            guard let post = StorablePost(octoPost: octoPost, aggregate: aggregate, userInteraction: userInteraction) else {
                throw InternalError.objectMalformed
            }
            try await postsDatabase.upsert(posts: [post])
        } catch {
            if let error = error as? RemoteClientError {
                if case .notFound = error {
                    try? await postsDatabase.delete(contentId: uuid)
                    _postDeletedPublisher.send()
                }
                throw .serverError(ServerError(remoteClientError: error))
            } else {
                throw .other(error)
            }
        }
    }

    public func fetchAdditionalData(ids: [String], incrementViewCount: Bool = false) async throws(ServerCallError) {
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        do {
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
            try await postsDatabase.update(additionalData: additionalData)
        } catch {
            if let error = error as? RemoteClientError {
                throw .serverError(ServerError(remoteClientError: error))
            } else {
                throw .other(error)
            }
        }
    }

    @discardableResult
    public func send(_ post: WritablePost) async throws(SendPost.Error) -> (Post, Data?) {
        guard validator.validate(post: post) else {
            throw .serverCall(.other(InternalError.objectMalformed))
        }
        guard networkMonitor.connectionAvailable else { throw .serverCall(.noNetwork) }

        do {
            var post = post
            var imageIsCompressed = false
            if case let .image(imageData) = post.attachment {
                let (resizedImgData, isCompressed) = ImageResizer.resizeIfNeeded(imageData: imageData)
                post.attachment = .image(resizedImgData)
                imageIsCompressed = isCompressed
            }
            let response = try await remoteClient.octoService.put(
                post: post.rwOctoObject(imageIsCompressed: imageIsCompressed),
                authenticationMethod: try authCallProvider.authenticatedMethod())

            switch response.result {
            case let .success(content):
                guard let finalPost = StorablePost(octoPost: content.post, aggregate: nil, userInteraction: nil) else {
                    throw SendComment.Error.serverCall(.other(nil))
                }
                try await postsDatabase.upsert(posts: [finalPost])
                _postSentPublisher.send()
                let imageData: Data? = if case let .image(imageData) = post.attachment { imageData } else { nil }
                return (Post(storablePost: finalPost, commentFeedsStore: commentFeedsStore), imageData)
            case let .fail(failure):
                throw SendPost.Error.validation(.init(from: failure))
            case .none:
                throw SendPost.Error.serverCall(.other(nil))
            }
        } catch {
            if let error = error as? SendPost.Error {
                throw error
            } else if let error = error as? RemoteClientError {
                throw .serverCall(.serverError(ServerError(remoteClientError: error)))
            } else {
                throw .serverCall(.other(error))
            }
        }
    }

    public func deletePost(postId: String) async throws(AuthenticatedActionError) {
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        do {
            _ = try await remoteClient.octoService.delete(
                post: postId,
                authenticationMethod: try authCallProvider.authenticatedMethod())

            try await postsDatabase.delete(contentId: postId)
            _postDeletedPublisher.send()
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

    public func toggleLike(post: Post) async throws(ToggleLike.Error) {
        guard networkMonitor.connectionAvailable else { throw .serverCall(.noNetwork) }
        do {
            if let likeId = post.userInteractions.userLikeId, likeId != UserInteractions.temporaryLikeId {
                do {
                    // first, remove the like in the db to have an immediate result.
                    try await postsDatabase.updateLikeId(newId: nil, contentId: post.uuid)
                    _ = try await remoteClient.octoService.unlike(
                        likeId: likeId,
                        authenticationMethod: try authCallProvider.authenticatedMethod())
                } catch {
                    guard let error = error as? RemoteClientError,
                       case .notFound = error else {
                        // revert the db change in case of error
                        try await postsDatabase.updateLikeId(newId: likeId, contentId: post.uuid)
                        throw error
                    }
                    // nothing to do: we ignore the notFound error, it is thrown because the post is already unliked
                }
            } else {
                do {
                    // prevent tapping on the like without good connection that increase the like count
                    if post.userInteractions.userLikeId != UserInteractions.temporaryLikeId {
                        // first, add a fake like in the db to have an immediate result.
                        try await postsDatabase.updateLikeId(newId: UserInteractions.temporaryLikeId,
                                                             contentId: post.uuid)
                    }
                    let response = try await remoteClient.octoService.like(
                        objectId: post.uuid,
                        authenticationMethod: try authCallProvider.authenticatedMethod())
                    switch response.result {
                    case let .success(content):
                        guard content.hasLike else {
                            throw SendComment.Error.serverCall(.other(nil))
                        }
                        // no need to update like count because it has been with the temporaryLikeId
                        try await postsDatabase.updateLikeId(newId: content.like.id,
                                                             contentId: post.uuid,
                                                             updateLikeCount: false)
                    case let .fail(failure):
                        throw ToggleLike.Error.validation(.init(from: failure))
                    case .none:
                        throw ToggleLike.Error.serverCall(.other(nil))
                    }
                } catch {
                    // revert the db change in case of error
                    try await postsDatabase.updateLikeId(newId: nil, contentId: post.uuid)
                    throw error
                }
            }
        } catch {
            if let error = error as? ToggleLike.Error {
                throw error
            } else if let error = error as? RemoteClientError {
                throw .serverCall(.serverError(ServerError(remoteClientError: error)))
            } else {
                throw .serverCall(.other(error))
            }
        }
    }

    public func vote(pollAnswerId: String, post: Post) async throws(PollVote.Error) {
        guard networkMonitor.connectionAvailable else { throw .serverCall(.noNetwork) }
        do {
            do {
                // first, add a fake vote in the db to have an immediate result.
                try await postsDatabase.updateVote(answerId: pollAnswerId, postId: post.uuid)
                let response = try await remoteClient.octoService.voteOnPoll(
                    objectId: post.uuid,
                    answerId: pollAnswerId,
                    authenticationMethod: try authCallProvider.authenticatedMethod())
                switch response.result {
                case let .success(content):
                    guard content.hasPollVote, content.pollVote.hasContent, content.pollVote.content.hasVote else {
                        throw SendComment.Error.serverCall(.other(nil))
                    }
                    // get the value from the backend just in case
                    let backendPollAnswerId = content.pollVote.content.vote.pollAnswerID
                    try await postsDatabase.updateVote(answerId: backendPollAnswerId, postId: post.uuid)
                case let .fail(failure):
                    throw PollVote.Error.validation(.init(from: failure))
                case .none:
                    throw PollVote.Error.serverCall(.other(nil))
                }
            } catch {
                // revert the db change in case of error
                try await postsDatabase.updateVote(answerId: nil, postId: post.uuid)
                throw error
            }
        } catch {
            if let error = error as? PollVote.Error {
                throw error
            } else if let error = error as? RemoteClientError {
                throw .serverCall(.serverError(ServerError(remoteClientError: error)))
            } else {
                throw .serverCall(.other(error))
            }
        }
    }

    public func getOrCreateClientObjectRelatedPostId(content: ClientPost)
    async throws(GetOrCreateClientPost.Error) -> String {
        do {
            // first check in the db if the post exists:
            if let post = try await postsDatabase.getClientObjectRelatedPost(objectId: content.clientObjectId) {
                // Without waiting for the answer, send the data to the backend, in case they want to update it
                Task {
                    do {
                        _ = try await remotelyGetOrCreateClientObjectRelatedPostId(content: content)
                    } catch {
                        if #available(iOS 14, *) { Logger.posts.debug("Error when sending bridge post: \(error)") }
                    }
                }
                return post.uuid
            } else {
                // the post is not in db yet, so ask the backend to get or create it
                return try await remotelyGetOrCreateClientObjectRelatedPostId(content: content)
            }
        } catch {
            if #available(iOS 14, *) { Logger.posts.debug("Error when getting/creating bridge post: \(error)") }
            if let error = error as? GetOrCreateClientPost.Error {
                throw error
            } else if let error = error as? RemoteClientError {
                throw .serverCall(.serverError(ServerError(remoteClientError: error)))
            } else {
                throw .serverCall(.other(error))
            }
        }
    }

    private func remotelyGetOrCreateClientObjectRelatedPostId(content: ClientPost)
    async throws(GetOrCreateClientPost.Error) -> String {
        guard networkMonitor.connectionAvailable else { throw .serverCall(.noNetwork) }
        do {
            var clientPost = content
            var imageIsCompressed = false
            if case let .localImage(imageData) = clientPost.attachment {
                let (resizedImgData, isCompressed) = ImageResizer.resizeIfNeeded(imageData: imageData)
                clientPost.attachment = .localImage(resizedImgData)
                imageIsCompressed = isCompressed
            }
            let response = try await remoteClient.octoService.getOrCreateBridgePost(
                post: clientPost.rwOctoPost(imageIsCompressed: imageIsCompressed),
                topicId: clientPost.topicId,
                clientToken: clientPost.signature,
                authenticationMethod: authCallProvider.authenticatedIfPossibleMethod())

            switch response.result {
            case let .success(content):
                guard let finalPost = StorablePost(octoPost: content.postBridge, aggregate: nil, userInteraction: nil) else {
                    throw SendComment.Error.serverCall(.other(nil))
                }
                try await postsDatabase.upsert(posts: [finalPost])
                return finalPost.uuid
            case let .fail(failure):
                throw GetOrCreateClientPost.Error.validation(.init(from: failure))
            case .none:
                throw GetOrCreateClientPost.Error.serverCall(.other(nil))
            }
        } catch {
            if let error = error as? GetOrCreateClientPost.Error {
                throw error
            } else if let error = error as? RemoteClientError {
                throw .serverCall(.serverError(ServerError(remoteClientError: error)))
            } else {
                throw .serverCall(.other(error))
            }
        }
    }
}

