//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import OctopusRemoteClient
import OctopusGrpcModels
import OctopusDependencyInjection
import os

extension Injected {
    static let topicsRepository = Injector.InjectedIdentifier<TopicsRepository>()
}

public class TopicsRepository: InjectableObject, @unchecked Sendable {
    public static let injectedIdentifier = Injected.topicsRepository

    @Published public private(set) var topics: [Topic] = []

    /// `true` iff at least one topic in `topics` has both `canAccess` and `canCreateChildren`.
    /// Defaults to `true` until `topics` resolves.
    /// Used by cross-group "create post" entry points to decide whether to render the button at all.
    @Published public private(set) var canCreateAnyPost: Bool = true

    /// Latest topics as delivered by the storage layer, before any debug section override is applied.
    private var storedTopics: [Topic] = []
    /// Names of the mock client sections injected by the debug override. Empty means no override.
    private var debugMockSectionNames: [String] = []

    private let topicsDatabase: TopicsDatabase
    private let authCallProvider: AuthenticatedCallProvider
    private let networkMonitor: NetworkMonitor
    private let remoteClient: OctopusRemoteClient
    private let postFeedsStore: PostFeedsStore
    private let sdkEventsEmitter: SdkEventsEmitter
    private var storage: Set<AnyCancellable> = []

    init(injector: Injector) {
        topicsDatabase = injector.getInjected(identifiedBy: Injected.topicsDatabase)
        authCallProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        networkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor)
        postFeedsStore = injector.getInjected(identifiedBy: Injected.postFeedsStore)
        sdkEventsEmitter = injector.getInjected(identifiedBy: Injected.sdkEventsEmitter)

        topicsDatabase.topicsPublisher()
            .removeDuplicates()
            .sink { [weak self] in
                guard let self else { return }
                storedTopics = $0.map { Topic(from: $0, postFeedsStore: self.postFeedsStore) }
                topics = decoratedWithDebugSections(storedTopics)
            }.store(in: &storage)

        $topics
            .dropFirst()
            .map { $0.contains { $0.permissions.canAccess && $0.permissions.canCreateChildren } }
            .removeDuplicates()
            .sink { [weak self] in self?.canCreateAnyPost = $0 }
            .store(in: &storage)
    }

    @discardableResult
    public func fetchTopics() async throws(ServerCallError) -> [Topic] {
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        do {
            let response = try await remoteClient.octoService
                .getTopics(authenticationMethod: authCallProvider.authenticatedIfPossibleMethod())
            let topics = [StorableTopic](
                from: response.topics,
                requesterCtxs: response.topicsRequesterCtxs,
                octoSections: response.sections
            )
            try await topicsDatabase.replaceAll(topics: topics)
            return decoratedWithDebugSections(topics.map { Topic(from: $0, postFeedsStore: postFeedsStore) })
        } catch {
            if #available(iOS 14, *) { Logger.groups.debug("Error when fetching groups: \(error)") }
            if let error = error as? RemoteClientError {
                throw .serverError(ServerError(remoteClientError: error))
            } else {
                throw .other(error)
            }
        }
    }

    /// Internal test affordance (exposed via an `@_spi` SDK entry point): locally redistributes the
    /// published topics into the given mock client sections, so the sample can exercise the sectioned
    /// group-list rendering (title padding + inter-section separator) without a backend that serves
    /// client sections. Pass an empty array to clear the override and fall back to the backend values.
    ///
    /// The first topic is left section-less (it renders the leading "no section" block, which has no
    /// separator), and the remaining topics are round-robined across the mock sections so at least two
    /// blocks render and every block after the first shows its separator.
    ///
    /// - Parameter mockSectionNames: the mock section titles to distribute topics into, or `[]` to clear.
    public func debugOverrideTopicSections(mockSectionNames: [String]) {
        debugMockSectionNames = mockSectionNames
        topics = decoratedWithDebugSections(storedTopics)
    }

    func decoratedWithDebugSections(_ topics: [Topic]) -> [Topic] {
        guard !debugMockSectionNames.isEmpty, !topics.isEmpty else { return topics }
        let sections = debugMockSectionNames.enumerated().map {
            Section(uuid: "debug-section-\($0.offset)", name: $0.element, position: $0.offset)
        }
        return topics.enumerated().map { index, topic in
            guard index > 0 else { return topic }
            let section = sections[(index - 1) % sections.count]
            return topic.withSections([section])
        }
    }

    public func syncFollowTopics(
        actions: [SyncFollowTopicAction]
    ) async throws(AuthenticatedActionError) -> [SyncFollowTopicResult] {
        guard !actions.isEmpty else { return [] }
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        do {
            let protoActions = actions.map { Com_Octopuscommunity_SyncFollowTopicAction(from: $0) }
            let response = try await remoteClient.userService.syncFollowTopics(
                actions: protoActions,
                authenticationMethod: try authCallProvider.authenticatedMethod())
            // Refresh the local cache so the published `groups` reflects the new state.
            do { _ = try await fetchTopics() } catch {
                if #available(iOS 14, *) {
                    Logger.groups.debug("Cache refresh after syncFollowTopics failed: \(error)")
                }
            }
            return response.results.map { SyncFollowTopicResult(from: $0) }
        } catch {
            if #available(iOS 14, *) {
                Logger.groups.debug("Error during syncFollowTopics: \(error)")
            }
            if let error = error as? AuthenticatedActionError {
                throw error
            } else if let error = error as? RemoteClientError {
                throw .serverError(ServerError(remoteClientError: error))
            } else {
                throw .other(error)
            }
        }
    }

    public func changeFollowStatus(topicId: String, follow: Bool) async throws(FollowTopic.Error) {
        guard networkMonitor.connectionAvailable else { throw .serverCall(.noNetwork) }
        guard let topic = topics.first(where: { $0.uuid == topicId }) else { throw .other(InternalError.objectNotFound) }
        guard topic.canChangeFollowStatus else { throw .other(InternalError.incorrectState) }

        do {
            do {
                // first, immediatly follow/unfollow the topic in db to see it in the UI
                try await topicsDatabase.changeIsFollowing(topicId: topicId, isFollowing: follow)

                let response: Com_Octopuscommunity_FollowUnfollowTopicResponse
                if follow {
                    response = try await remoteClient.userService.followTopic(
                        topicId: topicId, authenticationMethod: try authCallProvider.authenticatedMethod())
                } else {
                    response = try await remoteClient.userService.unfollowTopic(
                        topicId: topicId, authenticationMethod: try authCallProvider.authenticatedMethod())
                }
                switch response.result {
                case .success:
                    try await topicsDatabase.changeIsFollowing(topicId: topicId, isFollowing: follow)
                    sdkEventsEmitter.emit(.groupFollowingChanged)
                    sdkEventsEmitter.emit(.groupFollowingChanged(.init(groupId: topicId, followed: follow)))
                case let .fail(failure):
                    throw FollowTopic.Error.validation(.init(from: failure))
                case .none:
                    throw FollowTopic.Error.serverCall(.other(nil))
                }
            } catch {
                // revert the db change in case of error and fetch the topics in case a follow status have changed
                try? await topicsDatabase.changeIsFollowing(topicId: topicId, isFollowing: !follow)
                _ = try? await fetchTopics()
                throw error
            }
        } catch {
            if #available(iOS 14, *) { Logger.groups.debug("Error when changing following status of group \(topicId): \(error)") }
            if let error = error as? FollowTopic.Error {
                throw error
            } else if let error = error as? RemoteClientError {
                throw .serverCall(.serverError(ServerError(remoteClientError: error)))
            } else {
                throw .serverCall(.other(error))
            }
        }
    }
}
