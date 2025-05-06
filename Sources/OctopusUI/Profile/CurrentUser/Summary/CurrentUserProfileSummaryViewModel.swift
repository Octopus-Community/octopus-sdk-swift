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

    let hasInitialNotSeenNotifications: Bool

    let notifCenterViewModel: NotificationCenterViewModel

    let editConfig: EditConfig

    let octopus: OctopusSDK

    private var storage = [AnyCancellable]()

    init(octopus: OctopusSDK, mainFlowPath: MainFlowPath) {
        self.octopus = octopus
        notifCenterViewModel = NotificationCenterViewModel(octopus: octopus)
        if case let .sso(configuration) = octopus.core.connectionRepository.connectionMode,
           !configuration.appManagedFields.isEmpty {
            if configuration.appManagedFields.isStrictSubset(of: CoreProfileField.allCases) {
                editConfig = .mixed(configuration.appManagedFields, configuration.modifyUser)
            } else {
                editConfig = .editInApp(configuration.modifyUser)
            }
        } else {
            editConfig = .editInOctopus
        }

        hasInitialNotSeenNotifications = (octopus.core.profileRepository.profile?.notificationBadgeCount ?? 0) > 0

        Task {
            await fetchProfile()
        }

        Publishers.CombineLatest4(
            octopus.core.profileRepository.$profile.removeDuplicates(),
            $error,
            $isFetchingProfile,
            mainFlowPath.$isLocked
        ).sink { [unowned self] profile, currentError, isFetchingProfile, isLocked in
            guard let profile else {
                if currentError == nil && !isFetchingProfile && !isLocked {
                    dismiss = true
                }
                return
            }
            self.profile = profile
            // Update the view model only if feed id has changed
            let newestFirstPostsFeed = profile.newestFirstPostsFeed
            if postFeedViewModel?.feed.id != newestFirstPostsFeed.id {
                postFeedViewModel = PostFeedViewModel(octopus: octopus, postFeed: newestFirstPostsFeed,
                                                      displayModeratedPosts: true,
                                                      ensureConnected: { true })
            }
        }.store(in: &storage)
    }

    func refresh() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [self] in await postFeedViewModel?.refresh() }
            group.addTask { [self] in await notifCenterViewModel.refresh() }
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
}
