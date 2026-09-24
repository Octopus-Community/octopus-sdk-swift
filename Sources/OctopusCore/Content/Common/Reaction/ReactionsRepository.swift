//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import os
import OctopusRemoteClient
import OctopusDependencyInjection
import OctopusGrpcModels

extension Injected {
    static let reactionsRepository = Injector.InjectedIdentifier<ReactionsRepository>()
}

/// Lists who reacted on a content.
///
/// Stateless on purpose: nothing is persisted. The list is volatile (someone can react or unreact at any
/// moment) and is only ever shown in a transient sheet, so a cache would age badly for no benefit. Paging
/// state belongs to the caller, which holds one cursor per reaction tab.
public class ReactionsRepository: InjectableObject, @unchecked Sendable {
    public static let injectedIdentifier = Injected.reactionsRepository

    private let remoteClient: OctopusRemoteClient
    private let authCallProvider: AuthenticatedCallProvider
    private let networkMonitor: NetworkMonitor

    init(injector: Injector) {
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        authCallProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)
        networkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor)
    }

    /// Fetches one page of the members who reacted on `contentId`, most recent reaction first.
    ///
    /// The ordering, and the filtering by reaction kind, are the backend's: it owns the sort so that every
    /// page is consistent with the previous one.
    /// - Parameters:
    ///   - kind: restricts the list to a single reaction kind. `nil` lists every kind, for the "All" tab.
    ///   - cursor: `nil` for the first page, otherwise the previous page's ``ReactionsPage/nextCursor``.
    public func fetchReactions(contentId: String, kind: ReactionKind?, cursor: String?, pageSize: Int)
    async throws(ServerCallError) -> ReactionsPage {
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        do {
            let response = try await remoteClient.octoService.getReactionsPage(
                parentId: contentId,
                unicode: kind?.unicode,
                pageCursor: cursor,
                pageSize: UInt32(max(0, pageSize)),
                authenticationMethod: authCallProvider.authenticatedIfPossibleMethod())
            return ReactionsPage(
                reactions: response.reactions.map(ProfileReaction.init(from:)),
                // An empty cursor means "no more pages" just as much as an absent one does.
                nextCursor: response.hasNextPageCursor ? response.nextPageCursor.nilIfEmpty : nil)
        } catch {
            if #available(iOS 14, *) { Logger.content.debug("Error when fetching reactions: \(error)") }
            throw .serverError(ServerError(remoteClientError: error))
        }
    }
}
