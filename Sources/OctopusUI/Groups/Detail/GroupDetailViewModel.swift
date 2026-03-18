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
    @Published private(set) var group: GroupDetail
    @Published private(set) var error: DisplayableString?

    @Published var authenticationAction: ConnectedActionReplacement?
    var authenticationActionBinding: Binding<ConnectedActionReplacement?> {
        Binding(
            get: { self.authenticationAction },
            set: { self.authenticationAction = $0 }
        )
    }

    @Published private(set) var postFeedViewModel: PostFeedViewModel!
    var thisUserProfileId: String? {
        octopus.core.profileRepository.profile?.id
    }

    let octopus: OctopusSDK
    let connectedActionChecker: ConnectedActionChecker
    private let translationStore: ContentTranslationPreferenceStore

    private var storage = [AnyCancellable]()
    private var topics: [OctopusCore.Topic] = []

    init(octopus: OctopusSDK, topic: OctopusCore.Topic, mainFlowPath: MainFlowPath,
         translationStore: ContentTranslationPreferenceStore) {
        self.octopus = octopus
        self.group = .init(from: topic)
        self.translationStore = translationStore
        connectedActionChecker = ConnectedActionChecker(octopus: octopus)

        postFeedViewModel = PostFeedViewModel(
            octopus: octopus, postFeed: topic.feed,
            displayModeratedPosts: false,
            displayGroup: false,
            translationStore: translationStore,
            ensureConnected: { [weak self] action in
                guard let self else { return false }
                return self.ensureConnected(action: action)
            })

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
            .sink { [unowned self] in
                topics = $0
                guard let topic = $0.first(where: { $0.uuid == topic.uuid }) else { return }
                self.group = .init(from: topic)
                guard postFeedViewModel.feed.id != topic.feed.id else { return }
                postFeedViewModel = PostFeedViewModel(
                    octopus: octopus, postFeed: topic.feed,
                    displayModeratedPosts: false,
                    displayGroup: false,
                    translationStore: translationStore,
                    ensureConnected: { [weak self] action in
                        guard let self else { return false }
                        return self.ensureConnected(action: action)
                    })
            }.store(in: &storage)

        fetchTopics(isManual: false)
    }

    func toggleFollowGroup() {
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
            group.addTask { [self] in await postFeedViewModel.refresh() }

            await group.waitForAll()
        }
    }

    private func refreshFeed(isManual: Bool) {
        postFeedViewModel.refreshFeed(isManual: isManual)
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
    }
}
