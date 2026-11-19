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
    /// Whose profile the screen displays.
    let source: ProfileSummarySource
    /// The Octopus id of the member, published once known: at once for an Octopus id, once the lookup resolved it
    /// for a client user id. `nil` while the lookup runs and after it failed.
    @Published private(set) var profileId: String?
    let connectedActionChecker: ConnectedActionChecker

    private let translationStore: ContentTranslationPreferenceStore
    private var storage = [AnyCancellable]()
    private var profileStorage: AnyCancellable?
    private var commentsViewModelStorage: AnyCancellable?

    convenience init(octopus: OctopusSDK, translationStore: ContentTranslationPreferenceStore, profileId: String) {
        self.init(octopus: octopus, translationStore: translationStore, source: .profileId(profileId))
    }

    init(octopus: OctopusSDK, translationStore: ContentTranslationPreferenceStore, source: ProfileSummarySource) {
        self.octopus = octopus
        self.source = source
        self.translationStore = translationStore
        self.connectedActionChecker = ConnectedActionChecker(octopus: octopus)

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

        switch source {
        case let .profileId(profileId):
            track(profileId: profileId)
        case let .clientUserId(clientUserId):
            resolve(clientUserId: clientUserId)
        }
    }

    /// Displays the member once their Octopus id is known.
    private func track(profileId: String) {
        self.profileId = profileId
        let translationStore = self.translationStore
        profileStorage = Publishers.CombineLatest(
            octopus.core.profileRepository.getProfile(profileId: profileId).removeDuplicates(),
            octopus.core.profileRepository.profilePublisher.map { $0?.id }.removeDuplicates()
        )
        .sink { [unowned self] profile, currentUserId in
            let isCurrentUser = profileId == currentUserId
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
        }

        Task {
            await refreshProfile(manual: false)
        }
    }

    /// Looks the client user id up, then displays the member it belongs to, or the failure of the first load.
    private func resolve(clientUserId: String) {
        let profileRepository = octopus.core.profileRepository
        Task {
            let target = await resolveProfileSummaryTarget(clientUserId: clientUserId) {
                try await profileRepository.fetchProfile(byClientUserId: $0)?.id
            }
            switch target {
            case let .resolved(profileId):
                track(profileId: profileId)
            case let .lookupFailed(failure):
                loadFailure = failure
            }
        }
    }

    func refresh() async {
        // Nothing to refresh until the member is known: the lookup that failed is retried from the error state
        guard profileId != nil else { return }
        // if the refresh profile failed, do not refresh the feed (that will avoid having two error alerts)
        if await refreshProfile(manual: true) {
            await postFeedViewModel?.refresh()
        }
    }

    /// Re-runs the first load, from the error state's CTA.
    func retryFirstLoad() {
        loadFailure = nil
        guard profileId != nil else {
            // The lookup of the client user id is what failed
            if case let .clientUserId(clientUserId) = source {
                resolve(clientUserId: clientUserId)
            }
            return
        }
        Task { await refreshProfile(manual: false) }
    }

    /// Refresh the profile
    /// - Parameter manual: whether the refresh is a manual one
    /// - Returns: true if the refresh was successful, false otherwise
    @discardableResult
    private func refreshProfile(manual: Bool) async -> Bool {
        guard let profileId else { return false }
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
        guard let profileId else { return }
        do {
            try await octopus.core.profileRepository.blockUser(profileId: profileId)
            blockUserDone = true
        } catch {
            self.error = error.displayableMessage
        }
    }
}

/// Whose profile the profile screen of another member displays.
enum ProfileSummarySource: Equatable {
    /// The member's Octopus profile id: the screen opens directly.
    case profileId(String)
    /// The host app's own id for the member, resolved to an Octopus profile id first.
    case clientUserId(String)
}

extension ProfileSummarySource {
    /// The source of a profile opened by the host app, `nil` for the connected user's own profile, which another
    /// screen displays.
    init?(_ source: OctopusInitialScreen.ProfileScreenInfo.Source) {
        switch source {
        case .currentUser: return nil
        case let .clientUserId(clientUserId): self = .clientUserId(clientUserId)
        case let .profileId(profileId): self = .profileId(profileId)
        }
    }
}

/// What the lookup of a client user id gives the profile screen.
enum ProfileSummaryTarget: Equatable {
    /// The Octopus id of the member the client user id belongs to.
    case resolved(profileId: String)
    /// No member could be found: the screen shows this failure, never another member's profile.
    case lookupFailed(ScreenStateFailure)
}

/// Resolves a client user id to the member whose profile to display.
/// - Parameters:
///   - clientUserId: the host app's own id for the member
///   - lookup: returns the Octopus id of the member that has the client user id, `nil` when none has it
/// - Returns: the member, or the failure to display: an unknown id, a community that does not expose client user
///   ids or a server error give the neutral failure, no network gives its own
@MainActor
func resolveProfileSummaryTarget(clientUserId: String,
                                 lookup: (String) async throws -> String?) async -> ProfileSummaryTarget {
    do {
        guard let profileId = try await lookup(clientUserId) else { return .lookupFailed(.other) }
        return .resolved(profileId: profileId)
    } catch {
        return .lookupFailed(ScreenStateFailure(error))
    }
}
