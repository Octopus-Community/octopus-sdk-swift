//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus
import OctopusCore

enum GroupListContext: Equatable, Hashable {
    case displayFeed
    case groupSelection(selectedGroupId: String?, updateSelectedGroupId: (String?) -> Void)

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.displayFeed, .displayFeed): true
        case (.groupSelection, .groupSelection): true
        case (.groupSelection, .displayFeed),
            (.displayFeed, .groupSelection): false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .displayFeed:
            hasher.combine(0)
        case .groupSelection:
            hasher.combine(1)
        }
    }
}

@MainActor
class GroupListViewModel: ObservableObject {
    @Published var context: GroupListContext
    @Published private(set) var groups: GroupList?
    @Published private(set) var canChangeFollowStatusByGroupId: [String: Bool] = [:]
    @Published private(set) var isFollowedByGroupId: [String: Bool] = [:]
    @Published private(set) var error: DisplayableString?
    /// Set when the very first fetch fails, i.e. when there is no group to show in place of the error.
    @Published private(set) var loadFailure: ScreenStateFailure?

    let octopus: OctopusSDK

    private var storage = [AnyCancellable]()
    private var topics: [OctopusCore.Topic] = []

    init(octopus: OctopusSDK, context: GroupListContext) {
        self.octopus = octopus
        self.context = context

        octopus.core.topicsRepository.$topics
            .sink { [unowned self] in
                topics = $0
                computeCanChangeFollowStatusAndIsFollowed(topics: $0)
                groups = .init(from: filtered($0))
            }.store(in: &storage)

        fetchTopics()
    }

    /// Retries the first load, from the error state's CTA.
    func retryFirstLoad() {
        loadFailure = nil
        // The failure path left an empty list behind to hide the loader; clearing it brings the loader
        // back for the retry, instead of a bare page until the outcome lands.
        groups = nil
        fetchTopics()
    }

    func refresh() async {
        let refreshTopicsTask = Task { await fetchTopics() }
        await refreshTopicsTask.value
    }

    /// Invoked when a group row is tapped. If the group is locked (no access), invokes the
    /// host app's ``OctopusSDK/groupAccessDeniedCallback`` and returns `true`. Otherwise
    /// returns `false`, letting the caller proceed with navigation/selection.
    func handleGroupTap(groupId: String) -> Bool {
        guard let topic = topics.first(where: { $0.uuid == groupId }) else { return false }
        if !topic.permissions.canAccess {
            octopus.groupAccessDeniedCallback?(groupId)
            return true
        }
        return false
    }

    func changeFollowStatus(groupId: String, follow: Bool) {
        if let topic = topics.first(where: { $0.uuid == groupId }), !topic.permissions.canAccess {
            octopus.groupAccessDeniedCallback?(groupId)
            return
        }
        Task {
            await changeFollowStatus(groupId: groupId, follow: follow)
        }
    }

    private func fetchTopics() {
        Task {
            await fetchTopics()
        }
    }

    private func fetchTopics() async {
        do {
            let topics = try await octopus.core.topicsRepository.fetchTopics()
            computeCanChangeFollowStatusAndIsFollowed(topics: topics)
            groups = .init(from: filtered(topics))
            loadFailure = nil
        } catch {
            // Nothing listed yet: the error takes the list's place instead of an empty screen.
            if groups?.sections.isEmpty ?? true {
                loadFailure = ScreenStateFailure(error)
                groups = .init(from: [])
                return
            }
            if case .noNetwork = error {
                // Groups are already listed: a toast says so without replacing them (Screen states spec).
                octopus.core.toastsRepository.display(errorToast: .noNetwork)
            } else {
                octopus.core.toastsRepository.display(errorToast: .unknown)
            }
       }
    }

    private func computeCanChangeFollowStatusAndIsFollowed(topics: [OctopusCore.Topic]) {
        canChangeFollowStatusByGroupId = Dictionary(topics.map { ($0.uuid, $0.canChangeFollowStatus) },
                                                    uniquingKeysWith: { first, _ in first })
        isFollowedByGroupId = Dictionary(topics.map { ($0.uuid, $0.isFollowed) },
                                         uniquingKeysWith: { first, _ in first })
    }

    /// Returns topics filtered for the current context.
    /// For `.groupSelection` (the create-post topic picker), only topics where the user can
    /// post are shown. Inaccessible topics remain selectable so the tap handler can dispatch
    /// the access-denied callback.
    private func filtered(_ topics: [OctopusCore.Topic]) -> [OctopusCore.Topic] {
        switch context {
        case .displayFeed:
            return topics
        case .groupSelection:
            return topics.filter { $0.permissions.canCreateChildren }
        }
    }

    private func changeFollowStatus(groupId: String, follow: Bool) async {
        // if unfollow, we need to ensure that there will be at least one topic followed after this unfollow
        if !follow && topics.filter({ $0.isFollowed }).count <= 1 {
            self.error = .localizationKey("Group.Action.Unfollow.Error.LastFollowedGroup")
            return
        }
        do {
            try await octopus.core.topicsRepository.changeFollowStatus(topicId: groupId, follow: follow)
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
}
