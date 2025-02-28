//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus
import OctopusCore

@MainActor
class CurrentUserProfileSummaryViewModel: ObservableObject {
    @Published var profile: CurrentUserProfile?
    @Published private(set) var dismiss = false
    @Published var error: DisplayableString?
    // if true, no auto dismiss from this view model will be triggered
    @Published var preventAutoDismiss = false

    @Published private(set) var postFeedViewModel: PostFeedViewModel?

    @Published private var isFetchingProfile: Bool = false

    let octopus: OctopusSDK
    let editProfileCallback: ((OctopusCore.ConnectionMode.SSOConfiguration.ProfileField?) -> Void)?

    private var storage = [AnyCancellable]()

    init(octopus: OctopusSDK) {
        self.octopus = octopus
        if case let .sso(configuration) = octopus.core.connectionRepository.connectionMode,
           // only open the client's edit profile screen if there is at least one managed fields
           // TODO: when hybrid case is handled, do that if appManagedFields == ProfileFields.allCases
           !configuration.appManagedFields.isEmpty {
            editProfileCallback = configuration.modifyUser
        } else {
            editProfileCallback = nil
        }

        Task {
            isFetchingProfile = true
            do {
                try await octopus.core.profileRepository.fetchCurrentUserProfile()
            } catch {
                if let error = error as? AuthenticatedActionError, case .serverError(.notAuthenticated) = error {
                    self.error = error.displayableMessage
                }
            }
            isFetchingProfile = false
        }

        Publishers.CombineLatest3(
            octopus.core.profileRepository.$profile.removeDuplicates(),
            $error,
            $isFetchingProfile
        ).sink { [unowned self] profile, currentError, isFetchingProfile in
            guard let profile else {
                if currentError == nil && !isFetchingProfile && !preventAutoDismiss {
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
        isFetchingProfile = true
        do {
            await postFeedViewModel?.refresh()
            try await octopus.core.profileRepository.fetchCurrentUserProfile()
        } catch {
            self.error = error.displayableMessage

        }
        isFetchingProfile = false
    }
}
