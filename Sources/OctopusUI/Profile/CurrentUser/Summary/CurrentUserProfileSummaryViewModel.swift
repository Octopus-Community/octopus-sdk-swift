//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus
import OctopusCore

@MainActor
class CurrentUserProfileSummaryViewModel: ObservableObject {
    typealias CoreProfileField = OctopusCore.ConnectionMode.SSOConfiguration.ProfileField
    typealias EditProfileInAppBlock = (CoreProfileField?) -> Void

    enum EditConfig {
        case editInOctopus
        case mixed(Set<CoreProfileField>, EditProfileInAppBlock)
        case editInApp(EditProfileInAppBlock)
    }

    @Published var profile: DisplayableCurrentUserProfile?
    /// Set when the profile's first load failed with nothing cached to show. Without it the screen
    /// spins forever: nothing else on it can report the failure (Screen states spec).
    @Published private(set) var loadFailure: ScreenStateFailure?
    @Published var gamificationConfig: GamificationConfig?
    @Published var displayAccountAge = false
    @Published private(set) var editability = ProfileFieldsEditability(lock: .allEditable)
    /// Whether the community allows poll creation. Default `true`.
    @Published private(set) var pollsEnabled = true
    @Published private(set) var dismiss = false
    @Published var error: DisplayableString?

    @Published private(set) var postFeedViewModel: PostFeedViewModel?
    @Published private(set) var commentsViewModel: ProfileCommentsListViewModel?
    @Published private(set) var canCreatePost: Bool = true

    @Published private var isFetchingProfile: Bool = false
    @Published private(set) var editConfig: EditConfig = .editInOctopus

    @Published private(set) var forceDisplayGamificationRules: Bool = false

    /// Whether the connected profile is Octopus-owned (`.octopus` connection mode). Gates the
    /// overflow menu's account-settings and logout rows: an SSO profile is managed by the host app,
    /// so neither applies (mirrors the former `SettingsListViewModel.octopusOwnedProfile`).
    let octopusOwnedProfile: Bool
    @Published private(set) var logoutInProgress = false
    @Published var logoutDone = false

    let hasInitialNotSeenNotifications: Bool

    let notifCenterViewModel: NotificationCenterViewModel

    let octopus: OctopusSDK
    private let translationStore: ContentTranslationPreferenceStore
    private let gamificationRulesViewManager: GamificationRulesViewManager
    private var previousProfileId: String?

    private var storage = [AnyCancellable]()

    init(octopus: OctopusSDK, mainFlowPath: MainFlowPath, translationStore: ContentTranslationPreferenceStore,
         gamificationRulesViewManager: GamificationRulesViewManager) {
        self.octopus = octopus
        self.translationStore = translationStore
        self.gamificationRulesViewManager = gamificationRulesViewManager
        notifCenterViewModel = NotificationCenterViewModel(octopus: octopus)

        switch octopus.core.connectionRepository.connectionMode {
        case .octopus:
            octopusOwnedProfile = true
        case .sso:
            octopusOwnedProfile = false
        }

        hasInitialNotSeenNotifications = (octopus.core.profileRepository.profile?.notificationBadgeCount ?? 0) > 0

        // Lock the main flow while a logout is running / just completed, so the user can't navigate
        // on a half-torn-down session (mirrors the former `SettingsListViewModel` wiring).
        Publishers.CombineLatest(
            $logoutInProgress,
            $logoutDone
        ).sink {
            let shouldBeLocked = $0 || $1
            guard shouldBeLocked != mainFlowPath.isLocked else { return }
            mainFlowPath.isLocked = shouldBeLocked
        }.store(in: &storage)

        Task {
            await fetchProfile(manual: false)
        }

        octopus.core.configRepository.communityConfigPublisher
            .map { $0?.gamificationConfig }
            .removeDuplicates()
            .sink { [unowned self] in
                gamificationConfig = $0
                if gamificationConfig != nil {
                    forceDisplayGamificationRules = !gamificationRulesViewManager.rulesDisplayedOnce
                } else {
                    forceDisplayGamificationRules = false
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
            .map { ProfileFieldsEditability(lock: $0?.profileFieldsLock ?? .allEditable) }
            .removeDuplicates()
            .sink { [unowned self] in
                editability = $0
            }.store(in: &storage)

        octopus.core.configRepository
            .communityConfigPublisher
            .map { ($0?.contentOptions ?? .allEnabled).post.enablePolls }
            .removeDuplicates()
            .sink { [unowned self] in
                pollsEnabled = $0
            }.store(in: &storage)

        Publishers.CombineLatest4(
            octopus.core.profileRepository.profilePublisher.removeDuplicates(),
            $error,
            $isFetchingProfile,
            mainFlowPath.$isLocked
        ).sink { [unowned self] profile, _, _, _ in
            guard let profile else { return }
            self.profile = DisplayableCurrentUserProfile(from: profile)

            if case let .sso(configuration) = octopus.core.connectionRepository.connectionMode,
               !configuration.appManagedFields.isEmpty, !profile.isGuest {
                if configuration.appManagedFields.isStrictSubset(of: CoreProfileField.allCases) {
                    editConfig = .mixed(configuration.appManagedFields, configuration.modifyUser)
                } else {
                    editConfig = .editInApp(configuration.modifyUser)
                }
            } else {
                editConfig = .editInOctopus
            }

            // Update the view model only if feed id has changed
            let newestFirstPostsFeed = profile.newestFirstPostsFeed
            if postFeedViewModel?.feed.id != newestFirstPostsFeed.id {
                postFeedViewModel = PostFeedViewModel(octopus: octopus, postFeed: newestFirstPostsFeed,
                                                      displayModeratedPosts: true,
                                                      translationStore: translationStore,
                                                      ensureConnected: { _ in true })
            }
            // Comments tab — always shown on the connected user's own profile.
            if commentsViewModel?.feedId != profile.descCommentFeedId {
                commentsViewModel = ProfileCommentsListViewModel(
                    octopus: octopus, feedId: profile.descCommentFeedId, isOwnProfile: true)
            }
        }.store(in: &storage)

        octopus.core.sdkEventsEmitter.internalEvents
            .sink { [unowned self] internalEvent in
                switch internalEvent {
                case .contentCreated, .contentDeleted, .contentReactionChanged:
                    fetchProfile(manual: false)
                default: break
                }
            }.store(in: &storage)

        octopus.core.topicsRepository.$canCreateAnyPost
            .removeDuplicates()
            .sink { [weak self] in self?.canCreatePost = $0 }
            .store(in: &storage)
    }

    func refresh() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [self] in
                if await fetchProfile(manual: true) {
                    await postFeedViewModel?.refresh()
                }
            }
            group.addTask { [self] in await refreshNotifCenter() }

            await group.waitForAll()
        }
    }

    private func fetchProfile(manual: Bool) {
        Task {
            await fetchProfile(manual: manual)
        }
    }

    /// Re-runs the first load, from the error state's CTA.
    func retryFirstLoad() {
        loadFailure = nil
        fetchProfile(manual: false)
    }

    @discardableResult
    private func fetchProfile(manual: Bool) async -> Bool {
        isFetchingProfile = true
        defer { isFetchingProfile = false }
        do {
            try await octopus.core.profileRepository.fetchCurrentUserProfile()
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

    private func refreshNotifCenter() async {
        do {
            try await notifCenterViewModel.refresh()
        } catch {
            self.error = error.displayableMessage
        }
    }

    /// Logs the connected (Octopus-owned) user out, from the overflow menu's "Log out" row
    /// (mirrors the former `SettingsListViewModel.logout`). `logoutDone` drives the view's
    /// confirmation alert, which pops to the community root.
    func logout() {
        Task {
            logoutInProgress = true
            do {
                try await octopus.core.connectionRepository.logout(preventReconnection: false)
                logoutDone = true
                logoutInProgress = false
            } catch {
                logoutInProgress = false
                self.error = .localizationKey("Error.Unknown")
            }
        }
    }
}
