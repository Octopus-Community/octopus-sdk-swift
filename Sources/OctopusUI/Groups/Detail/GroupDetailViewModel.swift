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
    private var isConfirmingGroupDisappearance = false
    private var isLookingUpUnlistedGroup = false
    /// Whether the group on screen was fetched alone because the groups list leaves it out.
    private var showsUnlistedGroup = false

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

        octopus.core.sdkEventsEmitter.internalEvents
            .sink { [unowned self] internalEvent in
                // A group outside the list never leaves the topics: after a logout, only the server can tell
                // whether the next session may still read it.
                if internalEvent.clearedDisplayedContent, showsUnlistedGroup, group != nil {
                    confirmGroupDisappearance()
                }
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
        // if unfollow, we need to ensure that there will be at least one topic followed after this unfollow.
        // Topics that do not list this group (purged at logout, not fetched again yet) cannot tell.
        if !follow && topics.contains(where: { $0.uuid == topicId }) && topics.filter({ $0.isFollowed }).count <= 1 {
            self.error = .tonedKey(
                formal: "Group.Action.Unfollow.Error.LastFollowedGroup.Formal",
                informal: "Group.Action.Unfollow.Error.LastFollowedGroup.Informal")
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
                self.error = .unknownError
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
            // A group outside the list is never in it: its absence says nothing.
            if showsUnlistedGroup && group != nil { return }
            switch MissingGroupResolution(isConfirming: isConfirmingGroupDisappearance || isLookingUpUnlistedGroup,
                                          isShowingGroup: group != nil,
                                          hasFetchedTopicsOnce: hasFetchedTopicsOnce) {
            case .wait: break
            case .confirm: confirmGroupDisappearance()
            case .notFound:
                if !groupNotFound { lookUpUnlistedGroup() }
            }
            return
        }
        show(topic: topic, isListed: true)
    }

    private func show(topic: OctopusCore.Topic, isListed: Bool) {
        showsUnlistedGroup = !isListed
        groupNotFound = false
        let groupAccessGained = topic.permissions.canAccess && groupAccessLost
        groupAccessLost = !topic.permissions.canAccess
        group = GroupDetail(from: topic, isListed: isListed)
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

    /// Asks the server whether a group that vanished from the cache still exists: the logout purge also removes
    /// the groups, which the next session fetches again.
    /// Only a successful fetch without the group shows it as gone: a failed one keeps it on screen.
    private func confirmGroupDisappearance() {
        isConfirmingGroupDisappearance = true
        Task {
            let fetchedTopics: Result<[OctopusCore.Topic], ServerCallError>
            do throws(ServerCallError) {
                fetchedTopics = .success(try await octopus.core.topicsRepository.fetchTopics())
            } catch {
                fetchedTopics = .failure(error)
            }
            let check = VanishedContentCheck(fetchedIds: fetchedTopics.map { $0.map(\.uuid) }, id: groupId)
            // Gone from the list, which only holds the groups the user may see: it may still be readable.
            let unlistedLookup = check == .gone ? await lookUpUnlistedGroupOnServer() : nil
            isConfirmingGroupDisappearance = false
            switch check {
            case .stillAvailable:
                // From the fetched topics: the repository's list follows the database asynchronously, and may
                // still be the purged one, which would start another confirmation.
                resolveGroup(from: (try? fetchedTopics.get()) ?? [])
            case .gone:
                switch unlistedLookup ?? .notReadable {
                case let .readable(topic): show(topic: topic, isListed: false)
                case .notReadable: markGroupNotFound()
                case let .unanswered(failure): reportTopicsFetchFailure(failure)
                }
            case let .unanswered(failure):
                reportTopicsFetchFailure(failure)
            }
        }
    }

    /// The groups list leaves out the groups the user may not see, while reading a group only takes the Access
    /// right: a group missing from the list is fetched alone, and shown only when it can be read.
    private func lookUpUnlistedGroup() {
        isLookingUpUnlistedGroup = true
        Task {
            let lookup = await lookUpUnlistedGroupOnServer()
            isLookingUpUnlistedGroup = false
            switch lookup {
            case let .readable(topic):
                show(topic: topic, isListed: false)
            case .notReadable, .unanswered:
                // As before this lookup: a failed topics fetch was already reported.
                markGroupNotFound()
            }
        }
    }

    private func lookUpUnlistedGroupOnServer() async -> UnlistedGroupLookup<OctopusCore.Topic> {
        do throws(ServerCallError) {
            let topic = try await octopus.core.topicsRepository.fetchTopic(uuid: groupId)
            return UnlistedGroupLookup(topic: topic, canAccess: topic?.permissions.canAccess ?? false)
        } catch {
            return .unanswered(ScreenStateFailure(error))
        }
    }

    /// Shows the not-available state in place of the group: the header and the feed go with it, since they may
    /// show what the previous session could see.
    private func markGroupNotFound() {
        showsUnlistedGroup = false
        group = nil
        postFeedViewModel = nil
        groupAccessLost = false
        groupNotFound = true
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
            reportTopicsFetchFailure(ScreenStateFailure(error))
        }
        hasFetchedTopicsOnce = true
        // Re-resolve after fetch in case $topics fired before hasFetchedTopicsOnce was set
        resolveGroup(from: octopus.core.topicsRepository.topics)
    }

    private func reportTopicsFetchFailure(_ failure: ScreenStateFailure) {
        // The feed carries its own screen state for the same outage, so a toast here would report
        // it twice — the state under the toast saying exactly what the toast says.
        guard case .toast = LoadFailureChannel(hasVisibleContent: postFeedViewModel?.posts?.isEmpty == false) else {
            return
        }
        octopus.core.toastsRepository.display(errorToast: failure == .noNetwork ? .noNetwork : .unknown)
    }
}

/// What the group screen does when the topics it receives do not list its group.
enum MissingGroupResolution: Equatable {
    /// Nothing yet: a confirmation is already asking the server, or the first fetch has not answered.
    case wait
    /// The group was on screen: the server confirms it is gone first, since the logout purge also empties the
    /// groups, which the next session fetches again.
    case confirm
    /// No group on screen (never shown, or already shown as gone) and the topics were fetched without it.
    case notFound

    init(isConfirming: Bool, isShowingGroup: Bool, hasFetchedTopicsOnce: Bool) {
        if isConfirming {
            self = .wait
        } else if isShowingGroup {
            self = .confirm
        } else if hasFetchedTopicsOnce {
            self = .notFound
        } else {
            self = .wait
        }
    }
}

/// What the server answered about a group the groups list leaves out. The list only holds the groups the user may
/// see, while reading a group only takes the Access right.
enum UnlistedGroupLookup<Fetched> {
    /// The group exists and the user may read it: it is shown, outside the list.
    case readable(Fetched)
    /// No such group, or the user may not read it: the screen shows it as not available.
    case notReadable
    /// The server could not be asked.
    case unanswered(ScreenStateFailure)

    init(topic: Fetched?, canAccess: Bool) {
        if let topic, canAccess {
            self = .readable(topic)
        } else {
            self = .notReadable
        }
    }
}
