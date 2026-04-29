//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus
import OctopusCore

@MainActor
class GroupDetailViewModel: ObservableObject {
    @Published var scrollToTop = false
    @Published private(set) var group: GroupDetail?
    @Published private(set) var groupNotFound = false
    @Published private(set) var error: DisplayableString?

    @Published var authenticationAction: ConnectedActionReplacement?
    var authenticationActionBinding: Binding<ConnectedActionReplacement?> {
        Binding(
            get: { self.authenticationAction },
            set: { self.authenticationAction = $0 }
        )
    }

    @Published private(set) var postFeedViewModel: PostFeedViewModel?
    var thisUserProfileId: String? {
        octopus.core.profileRepository.profile?.id
    }

    var analyticsSource: SdkEvent.ScreenDisplayedContext.GroupDetailContext.Source {
        switch origin {
        case .clientApp: .clientApp
        case .sdk: .community
        }
    }

    let octopus: OctopusSDK
    let origin: GroupDetailNavigationOrigin
    let connectedActionChecker: ConnectedActionChecker
    let groupId: String
    private let translationStore: ContentTranslationPreferenceStore

    private var storage = [AnyCancellable]()
    private var topics: [OctopusCore.Topic] = []
    private var hasFetchedTopicsOnce = false

    init(octopus: OctopusSDK, groupId: String, mainFlowPath: MainFlowPath,
         translationStore: ContentTranslationPreferenceStore,
         origin: GroupDetailNavigationOrigin = .sdk) {
        self.octopus = octopus
        self.groupId = groupId
        self.translationStore = translationStore
        self.origin = origin
        connectedActionChecker = ConnectedActionChecker(octopus: octopus)

        // Synchronously resolve the topic from cached data if available
        resolveGroup(from: octopus.core.topicsRepository.topics)

        mainFlowPath.$path
            .prepend([])
            .zip(mainFlowPath.$path.removeDuplicates())
            .sink { [unowned self] previous, current in
                if case .createPost = previous.last, current == [] {
                    refreshFeed(isManual: false)
                    scrollToTop = true
                }
            }.store(in: &storage)

        octopus.core.topicsRepository.$topics
            .sink { [unowned self] allTopics in
                resolveGroup(from: allTopics)
            }.store(in: &storage)

        fetchTopics(isManual: false)
    }

    func toggleFollowGroup() {
        guard let group else { return }
        let shouldFollow = !group.isFollowed
        Task {
            await changeFollowStatus(topicId: group.id, follow: shouldFollow)
        }
    }

    private func changeFollowStatus(topicId: String, follow: Bool) async {
        // if unfollow, we need to ensure that there will be at least one topic followed after this unfollow
        if !follow && topics.filter({ $0.isFollowed }).count <= 1 {
            self.error = .localizationKey("Group.Action.Unfollow.Error.LastFollowedGroup")
            return
        }
        do {
            try await octopus.core.topicsRepository.changeFollowStatus(topicId: topicId, follow: follow)
        } catch {
            switch error {
            case let .validation(argumentError):
                for (displayKind, errors) in argumentError.errors {
                    let multiErrorLocalizedString = errors.map(\.localizedMessage).joined(separator: "\n- ")
                    switch displayKind {
                    case .alert:
                        self.error = .localizedString(multiErrorLocalizedString)
                    }
                }
            case let .serverCall(serverError):
                self.error = serverError.displayableMessage
            case .other:
                self.error = .localizationKey("Error.Unknown")
            }
       }
    }

    func ensureConnected(action: UserAction) -> Bool {
        connectedActionChecker.ensureConnected(action: action, actionWhenNotConnected: authenticationActionBinding)
    }

    func refresh() async {
        await withTaskGroup(of: Void.self) { group in
            // refresh of the topics is done in postFeedViewModel.refresh()
            if let postFeedViewModel {
                group.addTask { [postFeedViewModel] in await postFeedViewModel.refresh() }
            }

            await group.waitForAll()
        }
    }

    private func resolveGroup(from allTopics: [OctopusCore.Topic]) {
        topics = allTopics
        guard let topic = allTopics.first(where: { $0.uuid == groupId }) else {
            if hasFetchedTopicsOnce {
                groupNotFound = true
            }
            return
        }
        groupNotFound = false
        group = GroupDetail(from: topic)
        if let existingFeed = postFeedViewModel, existingFeed.feed.id == topic.feed.id {
            return
        }
        postFeedViewModel = PostFeedViewModel(
            octopus: octopus, postFeed: topic.feed,
            displayModeratedPosts: false,
            displayGroup: false,
            translationStore: translationStore,
            ensureConnected: { [weak self] action in
                guard let self else { return false }
                return self.ensureConnected(action: action)
            })
    }

    private func refreshFeed(isManual: Bool) {
        postFeedViewModel?.refreshFeed(isManual: isManual)
    }

    private func fetchTopics(isManual: Bool) {
        Task {
            await fetchTopics(isManual: isManual)
        }
    }

    private func fetchTopics(isManual: Bool) async {
        do {
            _ = try await octopus.core.topicsRepository.fetchTopics()
        } catch {
            if isManual {
                self.error = error.displayableMessage
            } else if case .noNetwork = error {
                octopus.core.toastsRepository.display(errorToast: .noNetwork)
            }
        }
        hasFetchedTopicsOnce = true
        // Re-resolve after fetch in case $topics fired before hasFetchedTopicsOnce was set
        resolveGroup(from: octopus.core.topicsRepository.topics)
    }
}
