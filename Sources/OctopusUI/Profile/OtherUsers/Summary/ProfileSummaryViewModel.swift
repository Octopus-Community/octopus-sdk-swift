//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import SwiftUI
import Octopus
import OctopusCore

@MainActor
class ProfileSummaryViewModel: ObservableObject {
    @Published var profile: DisplayableProfile?
    @Published var displayAccountAge: Bool = false
    @Published private(set) var dismiss = false
    @Published private(set) var error: DisplayableString?
    @Published private(set) var isLoading: Bool = false
    /// Set when the profile's first load failed with nothing cached to show. Without it the screen
    /// spins forever: nothing else on it can report the failure (Screen states spec).
    @Published private(set) var loadFailure: ScreenStateFailure?

    @Published var authenticationAction: ConnectedActionReplacement?
    var authenticationActionBinding: Binding<ConnectedActionReplacement?> {
        Binding(
            get: { self.authenticationAction },
            set: { self.authenticationAction = $0 }
        )
    }

    @Published var blockUserDone = false

    @Published private(set) var postFeedViewModel: PostFeedViewModel?
    @Published private(set) var commentsViewModel: ProfileCommentsListViewModel?
    /// Whether the Comments tab should be shown on this (other member's) profile. Requires the
    /// community config flag `showCommentsOnOtherProfiles`, a resolved comments feed, and that loading it
    /// wasn't refused server-side (`ProfileCommentsListViewModel.isForbidden`).
    @Published private(set) var showCommentsTab = false

    @Published private var showCommentsOnOtherProfiles = false
    @Published private var commentsForbidden = false

    let octopus: OctopusSDK
    let profileId: String
    let connectedActionChecker: ConnectedActionChecker

    private var storage = [AnyCancellable]()
    private var commentsViewModelStorage: AnyCancellable?

    init(octopus: OctopusSDK, translationStore: ContentTranslationPreferenceStore, profileId: String) {
        self.octopus = octopus
        self.profileId = profileId
        self.connectedActionChecker = ConnectedActionChecker(octopus: octopus)

        Publishers.CombineLatest(
            octopus.core.profileRepository.getProfile(profileId: profileId).removeDuplicates(),
            octopus.core.profileRepository.profilePublisher.map { $0?.id }.removeDuplicates()
        )
        .sink { [unowned self] profile, currentUserId in
            let isCurrentUser = self.profileId == currentUserId
            self.profile = profile.map { DisplayableProfile(from: $0, isCurrentUser: isCurrentUser) }
            if let newestFirstPostsFeed = profile?.newestFirstPostsFeed {
                // Update the view model only if feed id has changed
                if postFeedViewModel?.feed.id != newestFirstPostsFeed.id {
                    postFeedViewModel = PostFeedViewModel(
                        octopus: octopus, postFeed: newestFirstPostsFeed,
                        translationStore: translationStore,
                        ensureConnected: { [weak self] action in
                            guard let self else { return false }
                            return self.ensureConnected(action: action)
                        })
                }
            } else {
                postFeedViewModel = nil
            }

            // Comments tab — gated by `showCommentsOnOtherProfiles`; hidden if the profile has
            // no comment feed or if loading it is refused server-side (`isForbidden`, observed below).
            if let descCommentFeedId = profile?.descCommentFeedId, !descCommentFeedId.isEmpty {
                if commentsViewModel?.feedId != descCommentFeedId {
                    let commentsViewModel = ProfileCommentsListViewModel(
                        octopus: octopus, feedId: descCommentFeedId, isOwnProfile: false)
                    self.commentsViewModel = commentsViewModel
                    commentsForbidden = false
                    commentsViewModelStorage = commentsViewModel.$isForbidden
                        .removeDuplicates()
                        .sink { [unowned self] in commentsForbidden = $0 }
                }
            } else {
                commentsViewModel = nil
                commentsViewModelStorage = nil
                commentsForbidden = false
            }
        }.store(in: &storage)

        octopus.core.configRepository
            .communityConfigPublisher
            .map { $0?.displayAccountAge ?? false }
            .removeDuplicates()
            .sink { [unowned self] in
                displayAccountAge = $0
            }.store(in: &storage)

        octopus.core.configRepository
            .communityConfigPublisher
            .map { $0?.showCommentsOnOtherProfiles ?? false }
            .removeDuplicates()
            .sink { [unowned self] in
                showCommentsOnOtherProfiles = $0
            }.store(in: &storage)

        Publishers.CombineLatest3(
            $showCommentsOnOtherProfiles,
            $commentsViewModel,
            $commentsForbidden
        )
        .map { showCommentsOnOtherProfiles, commentsViewModel, commentsForbidden in
            showsOtherUserCommentsTab(showCommentsOnOtherProfiles: showCommentsOnOtherProfiles,
                                      hasCommentsFeed: commentsViewModel != nil,
                                      commentsForbidden: commentsForbidden)
        }
        .removeDuplicates()
        .sink { [unowned self] in showCommentsTab = $0 }
        .store(in: &storage)

        Task {
            await refreshProfile(manual: false)
        }
    }

    func refresh() async {
        // if the refresh profile failed, do not refresh the feed (that will avoid having two error alerts)
        if await refreshProfile(manual: true) {
            await postFeedViewModel?.refresh()
        }
    }

    /// Re-runs the first load, from the error state's CTA.
    func retryFirstLoad() {
        loadFailure = nil
        Task { await refreshProfile(manual: false) }
    }

    /// Refresh the profile
    /// - Parameter manual: whether the refresh is a manual one
    /// - Returns: true if the refresh was successful, false otherwise
    @discardableResult
    private func refreshProfile(manual: Bool) async -> Bool {
        do {
            try await octopus.core.profileRepository.fetchProfile(profileId: profileId)
            loadFailure = nil
        } catch {
            if profile == nil {
                loadFailure = ScreenStateFailure(error)
                return false
            }
            if manual {
                self.error = error.displayableMessage
            } else if case .serverError(.notAuthenticated) = error {
                self.error = error.displayableMessage
            } else if case .noNetwork = error,
                      case .toast = LoadFailureChannel(
                        hasVisibleContent: postFeedViewModel?.posts?.isEmpty == false) {
                // The feed shows its own screen state for the same outage; a toast over it would say
                // the same thing twice.
                octopus.core.toastsRepository.display(errorToast: .noNetwork)
            }
            return false
        }
        return true
    }

    func blockUser() {
        Task {
            await blockUser()
        }
    }

    func ensureConnected(action: UserAction) -> Bool {
        connectedActionChecker.ensureConnected(action: action, actionWhenNotConnected: authenticationActionBinding)
    }

    private func blockUser() async {
        do {
            try await octopus.core.profileRepository.blockUser(profileId: profileId)
            blockUserDone = true
        } catch {
            self.error = error.displayableMessage
        }
    }
}
