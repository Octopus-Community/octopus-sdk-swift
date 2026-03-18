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

    @Published var authenticationAction: ConnectedActionReplacement?
    var authenticationActionBinding: Binding<ConnectedActionReplacement?> {
        Binding(
            get: { self.authenticationAction },
            set: { self.authenticationAction = $0 }
        )
    }

    @Published var blockUserDone = false

    @Published private(set) var postFeedViewModel: PostFeedViewModel?

    let octopus: OctopusSDK
    let profileId: String
    let connectedActionChecker: ConnectedActionChecker

    private var storage = [AnyCancellable]()

    init(octopus: OctopusSDK, translationStore: ContentTranslationPreferenceStore, profileId: String) {
        self.octopus = octopus
        self.profileId = profileId
        self.connectedActionChecker = ConnectedActionChecker(octopus: octopus)

        octopus.core.profileRepository.getProfile(profileId: profileId)
            .removeDuplicates()
            .sink { [unowned self] in
                self.profile = $0.map { DisplayableProfile(from: $0) }
                if let newestFirstPostsFeed = $0?.newestFirstPostsFeed {
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
            }.store(in: &storage)

        octopus.core.configRepository
            .communityConfigPublisher
            .map { $0?.displayAccountAge ?? false }
            .removeDuplicates()
            .sink { [unowned self] in
                displayAccountAge = $0
            }.store(in: &storage)

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

    /// Refresh the profile
    /// - Parameter manual: whether the refresh is a manual one
    /// - Returns: true if the refresh was successful, false otherwise
    @discardableResult
    private func refreshProfile(manual: Bool) async -> Bool {
        do {
            try await octopus.core.profileRepository.fetchProfile(profileId: profileId)
        } catch {
            if manual {
                self.error = error.displayableMessage
            } else if case .serverError(.notAuthenticated) = error {
                self.error = error.displayableMessage
            } else if case .noNetwork = error {
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
