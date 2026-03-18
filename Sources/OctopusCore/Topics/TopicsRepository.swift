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
            .replaceError(with: [])
            .removeDuplicates()
            .sink { [weak self] in
                guard let self else { return }
                topics = $0.map { Topic(from: $0, postFeedsStore: postFeedsStore) }
            }.store(in: &storage)
    }

    @discardableResult
    public func fetchTopics() async throws(ServerCallError) -> [Topic] {
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        do {
            let response = try await remoteClient.octoService
                .getTopics(authenticationMethod: authCallProvider.authenticatedIfPossibleMethod())
            let topics = [StorableTopic](from: response.topics, octoSections: response.sections)
            try await topicsDatabase.replaceAll(topics: topics)
            return topics.map { Topic(from: $0, postFeedsStore: postFeedsStore) }
        } catch {
            if #available(iOS 14, *) { Logger.groups.debug("Error when fetching groups: \(error)") }
            if let error = error as? RemoteClientError {
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
