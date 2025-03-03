//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus
import OctopusCore

@MainActor
class ProfileSummaryViewModel: ObservableObject {
    @Published var profile: Profile?
    @Published private(set) var dismiss = false
    @Published private(set) var error: DisplayableString?
    @Published private(set) var isLoading: Bool = false

    @Published var openLogin = false
    @Published var openCreateProfile = false

    @Published var blockUserDone = false

    @Published private(set) var postFeedViewModel: PostFeedViewModel?

    @Published private(set) var ssoError: DisplayableString? // TODO: Delete when router is fully used

    let octopus: OctopusSDK
    let profileId: String

    private var storage = [AnyCancellable]()

    init(octopus: OctopusSDK, profileId: String) {
        self.octopus = octopus
        self.profileId = profileId

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
                            ensureConnected: { [weak self] in
                                guard let self else { return false }
                                return self.ensureConnected()
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

    func ensureConnected() -> Bool {
        switch octopus.core.connectionRepository.connectionState {
        case .notConnected, .magicLinkSent:
            if case let .sso(config) = octopus.core.connectionRepository.connectionMode {
                config.loginRequired()
            } else {
                openLogin = true
            }
        case let .clientConnected(_, error):
            switch error {
            case let .detailedErrors(errors):
                if let error = errors.first(where: { $0.reason == .userBanned }) {
                    ssoError = .localizedString(error.message)
                } else {
                    fallthrough
                }
            default:
                ssoError = .localizationKey("Connection.SSO.Error.Unknown")
            }
        case .profileCreationRequired:
            openCreateProfile = true
        case .connected:
            return true
        }
        return false
    }

    // TODO: Delete when router is fully used
    func linkClientUserToOctopusUser() {
        Task {
            await linkClientUserToOctopusUser()
        }
    }

    // TODO: Delete when router is fully used
    private func linkClientUserToOctopusUser() async {
        do {
            try await octopus.core.connectionRepository.linkClientUserToOctopusUser()
        } catch {
            switch error {
            case let .detailedErrors(errors):
                if let error = errors.first(where: { $0.reason == .userBanned }) {
                    ssoError = .localizedString(error.message)
                } else {
                    fallthrough
                }
            default:
                ssoError = .localizationKey("Connection.SSO.Error.Unknown")
            }
        }
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
