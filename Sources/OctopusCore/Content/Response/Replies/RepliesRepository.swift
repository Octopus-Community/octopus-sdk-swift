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
    static let repliesRepository = Injector.InjectedIdentifier<RepliesRepository>()
}

public class RepliesRepository: InjectableObject, @unchecked Sendable {
    public static let injectedIdentifier = Injected.repliesRepository

    public var replySentPublisher: AnyPublisher<Reply, Never> {
        _replySentPublisher.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
    private let _replySentPublisher = PassthroughSubject<Reply, Never>()

    public var replyDeletedPublisher: AnyPublisher<Reply?, Never> {
        _replyDeletedPublisher.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
    private let _replyDeletedPublisher = PassthroughSubject<Reply?, Never>()

    private let remoteClient: OctopusRemoteClient
    private let authCallProvider: AuthenticatedCallProvider
    private let repliesDatabase: RepliesDatabase
    private let networkMonitor: NetworkMonitor
    private let validator: Validators.Reply
    private let userInteractionsDelegate: UserInteractionsDelegate

    init(injector: Injector) {
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        authCallProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)
        repliesDatabase = injector.getInjected(identifiedBy: Injected.repliesDatabase)
        networkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor)
        validator = injector.getInjected(identifiedBy: Injected.validators).reply
        userInteractionsDelegate = UserInteractionsDelegate(injector: injector)
    }

    @discardableResult
    public func send(_ reply: WritableReply) async throws(SendReply.Error) -> (Reply, Data?) {
        guard validator.validate(reply: reply) else {
            throw .serverCall(.other(InternalError.objectMalformed))
        }
        guard networkMonitor.connectionAvailable else { throw .serverCall(.noNetwork) }

        do {
            var reply = reply
            if let imageData = reply.imageData {
                let (resizedImgData, isCompressed) = ImageResizer.resizeIfNeeded(imageData: imageData)
                reply.imageData = resizedImgData
                reply.isImageCompressed = isCompressed
            }
            let response = try await remoteClient.octoService.put(
                reply: reply.rwOctoObject(),
                authenticationMethod: try authCallProvider.authenticatedMethod())

            switch response.result {
            case let .success(content):
                guard let finalReply = StorableReply(octoReply: content.reply, aggregate: nil, userInteraction: nil) else {
                    throw SendReply.Error.serverCall(.other(nil))
                }
                try await repliesDatabase.upsert(replies: [finalReply])
                let newReply = Reply(storableComment: finalReply)
                _replySentPublisher.send(newReply)
                return (newReply, reply.imageData)
            case let .fail(failure):
                throw SendReply.Error.validation(.init(from: failure))
            case .none:
                throw SendReply.Error.serverCall(.other(nil))
            }
        } catch {
            if let error = error as? SendReply.Error {
                throw error
            } else if let error = error as? RemoteClientError {
                throw .serverCall(.serverError(ServerError(remoteClientError: error)))
            } else {
                throw .serverCall(.other(error))
            }
        }
    }

    public func deleteReply(replyId: String) async throws(AuthenticatedActionError) {
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        do {
            _ = try await remoteClient.octoService.delete(
                reply: replyId,
                authenticationMethod: try authCallProvider.authenticatedMethod())

            let reply = try? await repliesDatabase.getReplies(ids: [replyId]).first
                .map { Reply(storableComment: $0) }

            try await repliesDatabase.delete(replyId: replyId)
            _replyDeletedPublisher.send(reply)
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
            try await repliesDatabase.update(additionalData: additionalData)
        } catch {
            if let error = error as? RemoteClientError {
                throw .serverError(ServerError(remoteClientError: error))
            } else {
                throw .other(error)
            }
        }
    }

    public func set(reaction: ReactionKind?, reply: Reply) async throws(Reaction.Error) {
        try await userInteractionsDelegate.set(reaction: reaction, content: reply)
    }
}
