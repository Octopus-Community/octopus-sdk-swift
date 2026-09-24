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
    @Published private(set) var groupAccessLost = false
    @Published private(set) var canCreateAnyPost: Bool = true
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

    /// Whether a post was created during the currently-open composer session. Reset when the composer
    /// opens, set when a `.postCreated` event is received. Used to scroll to top only on a real creation.
    private var didCreatePostInComposer = false

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
                if case .createPost = current.last {
                    // The composer just opened: start tracking whether a post gets created this session.
                    didCreatePostInComposer = false
                } else if case .createPost = previous.last, current == [] {
                    // The composer was dismissed back to the feed: always refresh, but only scroll to top
                    // if a post was actually created (cancel via Back / swipe-down keeps the scroll).
                    refreshFeed()
                    scrollToTop = FeedComposerScrollPolicy.shouldScrollToTop(
                        previousLast: previous.last, current: current, didCreatePost: didCreatePostInComposer)
                }
            }.store(in: &storage)

        octopus.core.sdkEventsEmitter.events
            .sink { [unowned self] event in
                if case .postCreated = event { didCreatePostInComposer = true }
            }.store(in: &storage)

        octopus.core.topicsRepository.$topics
            .sink { [unowned self] allTopics in
                resolveGroup(from: allTopics)
            }.store(in: &storage)

        octopus.core.topicsRepository.$canCreateAnyPost
            .removeDuplicates()
            .sink { [weak self] in self?.canCreateAnyPost = $0 }
            .store(in: &storage)

        fetchTopics()
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
        let groupAccessGained = topic.permissions.canAccess && groupAccessLost
        groupAccessLost = !topic.permissions.canAccess
        group = GroupDetail(from: topic)
        if let existingFeed = postFeedViewModel, existingFeed.feed.id == topic.feed.id, !groupAccessGained {
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

    private func refreshFeed() {
        postFeedViewModel?.refreshFeed()
    }

    private func fetchTopics() {
        Task {
            await fetchTopics()
        }
    }

    private func fetchTopics() async {
        do {
            _ = try await octopus.core.topicsRepository.fetchTopics()
        } catch {
            // The feed carries its own screen state for the same outage, so a toast here would report
            // it twice — the state under the toast saying exactly what the toast says.
            if case .toast = LoadFailureChannel(hasVisibleContent: postFeedViewModel?.posts?.isEmpty == false) {
                if case .noNetwork = error {
                    octopus.core.toastsRepository.display(errorToast: .noNetwork)
                } else {
                    octopus.core.toastsRepository.display(errorToast: .unknown)
                }
            }
        }
        hasFetchedTopicsOnce = true
        // Re-resolve after fetch in case $topics fired before hasFetchedTopicsOnce was set
        resolveGroup(from: octopus.core.topicsRepository.topics)
    }
}
