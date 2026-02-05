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
    private let userInteractionsDelegate: UserInteractionsDelegate
    private let gamificationRepository: GamificationRepository
    private let sdkEventsEmitter: SdkEventsEmitter

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
        gamificationRepository = injector.getInjected(identifiedBy: Injected.gamificationRepository)
        sdkEventsEmitter = injector.getInjected(identifiedBy: Injected.sdkEventsEmitter)

        commentFeedsStore = injector.getInjected(identifiedBy: Injected.commentFeedsStore)
        userInteractionsDelegate = UserInteractionsDelegate(injector: injector)
    }

    public func getPost(uuid: String) -> AnyPublisher<Post?, Error> {
        return Publishers.CombineLatest(
            postsDatabase.postPublisher(uuid: uuid),
            blockedUserIdsProvider.blockedUserIdsPublisher.setFailureType(to: Error.self)
        )
        .map { [unowned self] in
            guard let storablePost = $0 else { return nil }
            guard !storablePost.author.isBlocked(in: $1) else { return nil }
            return Post(storablePost: storablePost, commentFeedsStore: commentFeedsStore, featuredComment: nil)
        }.eraseToAnyPublisher()
    }

    public func getPostValue(uuid: String) async throws -> Post? {
        guard let storablePost = try await postsDatabase.getPosts(ids: [uuid]).first else { return nil }
        return Post(storablePost: storablePost, commentFeedsStore: commentFeedsStore, featuredComment: nil)
    }

    public func getClientObjectRelatedPost(clientObjectId: String) -> AnyPublisher<Post?, Error> {
        postsDatabase.clientObjectRelatedPostPublisher(objectId: clientObjectId)
            .map { [unowned self] in
                guard let storablePost = $0 else { return nil }
                return Post(storablePost: storablePost, commentFeedsStore: commentFeedsStore, featuredComment: nil)
            }
            .eraseToAnyPublisher()
    }

    public func fetchPost(uuid: String, hasVideo: Bool, incrementViewCount: Bool = false)
    async throws(ServerCallError) {
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        do {
            let response = try await remoteClient.octoService.get(
                octoObjectInfo: OctoObjectInfo(id: uuid, hasVideo: hasVideo),
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
    
    /// Fetch additional data
    /// - Parameters:
    ///   - ids: list of tuple containing the id of the object and a boolean to know if the object has a video
    ///   - incrementViewCount: whether to increment the view count
    public func fetchAdditionalData(ids: [(id: String, hasVideo: Bool)],
                                    incrementViewCount: Bool = false) async throws(ServerCallError) {
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        do {
            let batchResponse = try await remoteClient.octoService.getBatch(
                octoObjectInfos: ids.map { OctoObjectInfo(id: $0, hasVideo: $1) },
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
                let createdPost = Post(storablePost: finalPost, commentFeedsStore: commentFeedsStore, featuredComment: nil)
                sdkEventsEmitter.emit(.contentCreated(content: createdPost))
                sdkEventsEmitter.emit(.postCreated(.init(from: createdPost)))
                gamificationRepository.register(action: .post)
                return (createdPost, imageData)
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

            let post = try? await postsDatabase.getPosts(ids: [postId]).first
                .map { Post(storablePost: $0, commentFeedsStore: commentFeedsStore, featuredComment: nil) }

            try await postsDatabase.delete(contentId: postId)
            _postDeletedPublisher.send()
            sdkEventsEmitter.emit(.contentDeleted(content: post))
            sdkEventsEmitter.emit(.contentDeleted(.init(contentId: postId, coreKind: .post)))
            gamificationRepository.unregister(action: .post)
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

    public func set(reaction: ReactionKind?, post: Post, parentIsTranslated: Bool) async throws(Reaction.Error) {
        try await userInteractionsDelegate.set(reaction: reaction, content: post,
                                               parentIsTranslated: parentIsTranslated)
    }

    public func vote(pollAnswerId: String, post: Post, parentIsTranslated: Bool) async throws(PollVote.Error) {
        guard networkMonitor.connectionAvailable else { throw .serverCall(.noNetwork) }
        do {
            do {
                // first, add a fake vote in the db to have an immediate result.
                try await postsDatabase.updateVote(answerId: pollAnswerId, postId: post.uuid)
                let response = try await remoteClient.octoService.voteOnPoll(
                    objectId: post.uuid,
                    answerId: pollAnswerId,
                    parentIsTranslated: parentIsTranslated,
                    authenticationMethod: try authCallProvider.authenticatedMethod())
                switch response.result {
                case let .success(content):
                    guard content.hasPollVote, content.pollVote.hasContent, content.pollVote.content.hasVote else {
                        throw SendComment.Error.serverCall(.other(nil))
                    }
                    // get the value from the backend just in case
                    let backendPollAnswerId = content.pollVote.content.vote.pollAnswerID
                    try await postsDatabase.updateVote(answerId: backendPollAnswerId, postId: post.uuid)
                    sdkEventsEmitter.emit(.pollVoted(.init(contentId: post.uuid, optionId: pollAnswerId)))
                    gamificationRepository.register(action: .vote)
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
        try await getOrCreateClientObjectRelatedPost(content: content).uuid
    }

    public func getOrCreateClientObjectRelatedPost(content: ClientPost)
    async throws(GetOrCreateClientPost.Error) -> Post {
        do {
            return try await remotelyGetOrCreateClientObjectRelatedPost(content: content)
        } catch {
            if #available(iOS 14, *) { Logger.posts.debug("Error when getting/creating bridge post: \(error)") }
            // in case of error, try to return the local post if we have it
            if let post = try? await postsDatabase.getClientObjectRelatedPost(objectId: content.clientObjectId) {
                return Post(storablePost: post, commentFeedsStore: commentFeedsStore, featuredComment: nil)
            }
            // if we don't have the local post or if it fails, throw the original error
            throw error
        }
    }

    private func remotelyGetOrCreateClientObjectRelatedPost(content: ClientPost)
    async throws(GetOrCreateClientPost.Error) -> Post {
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
                let aggregate = content.hasAggregate ? content.aggregate : nil
                guard let finalPost = StorablePost(octoPost: content.postBridge, aggregate: aggregate, userInteraction: nil) else {
                    throw SendComment.Error.serverCall(.other(nil))
                }
                try await postsDatabase.upsert(posts: [finalPost])
                return Post(storablePost: finalPost, commentFeedsStore: commentFeedsStore, featuredComment: nil)
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

