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
    @Published var profile: Profile?
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
            .replaceError(with: nil)
            .removeDuplicates()
            .sink { [unowned self] in
                self.profile = $0
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

        Task {
            do {
                try await octopus.core.profileRepository.fetchProfile(profileId: profileId)
            } catch {
                if let error = error as? ServerCallError, case .serverError(.notAuthenticated) = error {
                    self.error = error.displayableMessage
                }
            }
        }
    }

    func refresh() async {
        do {
            try await octopus.core.profileRepository.fetchProfile(profileId: profileId)
            await postFeedViewModel?.refresh()
        } catch {
            self.error = error.displayableMessage
        }
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
