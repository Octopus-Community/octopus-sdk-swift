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

    @Published var profile: CurrentUserProfile?
    @Published private(set) var dismiss = false
    @Published var error: DisplayableString?

    @Published private(set) var postFeedViewModel: PostFeedViewModel?

    @Published private var isFetchingProfile: Bool = false
    @Published private(set) var editConfig: EditConfig = .editInOctopus

    let hasInitialNotSeenNotifications: Bool

    let notifCenterViewModel: NotificationCenterViewModel

    let octopus: OctopusSDK
    private let translationStore: ContentTranslationPreferenceStore
    private var previousProfileId: String?

    private var storage = [AnyCancellable]()

    init(octopus: OctopusSDK, mainFlowPath: MainFlowPath, translationStore: ContentTranslationPreferenceStore) {
        self.octopus = octopus
        self.translationStore = translationStore
        notifCenterViewModel = NotificationCenterViewModel(octopus: octopus)

        hasInitialNotSeenNotifications = (octopus.core.profileRepository.profile?.notificationBadgeCount ?? 0) > 0

        Task {
            await fetchProfile()
        }

        Publishers.CombineLatest4(
            octopus.core.profileRepository.profilePublisher.removeDuplicates(),
            $error,
            $isFetchingProfile,
            mainFlowPath.$isLocked
        ).sink { [unowned self] profile, currentError, isFetchingProfile, isLocked in
            guard let profile else { return }
            self.profile = profile

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
                                                      ensureConnected: { _ in true }) // TODO Djavan: can we be sure that we are fully authorized to post?
            }
        }.store(in: &storage)
    }

    func refresh() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [self] in await postFeedViewModel?.refresh() }
            group.addTask { [self] in await refreshNotifCenter() }
            group.addTask { [self] in await fetchProfile() }

            await group.waitForAll()
        }
    }

    private func fetchProfile(onlyCatchNotAuthenticatedError: Bool = false) async {
        isFetchingProfile = true
        do {
            try await octopus.core.profileRepository.fetchCurrentUserProfile()
        } catch {
            if !onlyCatchNotAuthenticatedError {
                self.error = error.displayableMessage
            } else if case .serverError(.notAuthenticated) = error {
                self.error = error.displayableMessage
            }
        }
        isFetchingProfile = false
    }

    private func refreshNotifCenter() async {
        do {
            try await notifCenterViewModel.refresh()
        } catch {
            self.error = error.displayableMessage
        }
    }
}
