//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusRemoteClient
import OctopusGrpcModels
import SwiftProtobuf
import OctopusDependencyInjection
import os

class UserInteractionsDelegate {
    private let remoteClient: OctopusRemoteClient
    private let authCallProvider: AuthenticatedCallProvider
    private let octoObjectsDatabase: OctoObjectsDatabase
    private let networkMonitor: NetworkMonitor

    init(injector: Injector) {
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        octoObjectsDatabase = injector.getInjected(identifiedBy: Injected.postsDatabase)
        networkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor)
        authCallProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)
    }

    func set(reaction: ReactionKind?, content: OctopusContent, parentIsTranslated: Bool) async throws(Reaction.Error) {
        guard networkMonitor.connectionAvailable else { throw .serverCall(.noNetwork) }
        do {
            let existingReaction = content.userInteractions.reaction
            if let reaction {
                do {
                    // first, add a fake reaction in the db to have an immediate result.
                    try await octoObjectsDatabase.update(
                        userReaction: UserReaction(kind: reaction, id: UserInteractions.temporaryReactionId),
                        contentId: content.uuid)
                    let response = try await remoteClient.octoService.react(
                        reactionKind: reaction.unicode,
                        objectId: content.uuid,
                        parentIsTranslated: parentIsTranslated,
                        authenticationMethod: try authCallProvider.authenticatedMethod())
                    switch response.result {
                    case let .success(receivedContent):
                        guard receivedContent.hasReaction, receivedContent.reaction.content.hasReaction else {
                            throw Reaction.Error.serverCall(.other(nil))
                        }
                        // no need to update like count because it has been with the temporaryLikeId
                        let reactionId = receivedContent.reaction.id
                        let receivedReaction = receivedContent.reaction.content.reaction
                        try await octoObjectsDatabase.update(
                            userReaction: UserReaction(
                                kind: ReactionKind(unicode: receivedReaction.unicode),
                                id: reactionId),
                            contentId: content.uuid,
                            updateReactionCount: false)
                    case let .fail(failure):
                        throw Reaction.Error.validation(.init(from: failure))
                    case .none:
                        throw Reaction.Error.serverCall(.other(nil))
                    }
                } catch {
                    // revert the db change in case of error
                    try await octoObjectsDatabase.update(userReaction: existingReaction, contentId: content.uuid)
                    throw error
                }
            } else if let existingReaction {
                do {
                    // first, remove the reaction in the db to have an immediate result.
                    try await octoObjectsDatabase.update(userReaction: nil, contentId: content.uuid)
                    _ = try await remoteClient.octoService.deleteReaction(
                        reactionId: existingReaction.id,
                        authenticationMethod: try authCallProvider.authenticatedMethod())
                } catch {
                    guard let error = error as? RemoteClientError,
                          case .notFound = error else {
                        // revert the db change in case of error
                        try await octoObjectsDatabase.update(userReaction: existingReaction, contentId: content.uuid)
                        throw error
                    }
                    // nothing to do: we ignore the notFound error, it is thrown because the post is already unliked
                }
            } else {
                // State error: deleting a reaction when there is no reaction currently stored
                throw InternalError.incorrectState
            }
        } catch {
            if let error = error as? Reaction.Error {
                throw error
            } else if let error = error as? RemoteClientError {
                throw .serverCall(.serverError(ServerError(remoteClientError: error)))
            } else {
                throw .serverCall(.other(error))
            }
        }
    }
}
