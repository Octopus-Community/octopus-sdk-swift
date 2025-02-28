//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus
import OctopusCore
import UIKit

@MainActor
class PostListViewModel: ObservableObject {
    @Published var openLogin = false
    @Published var openCreateProfile = false
    @Published var openCreatePost = false
    @Published var openUserProfile = false
    @Published private(set) var ssoError: DisplayableString? // TODO: Delete when router is fully used

    @Published var scrollToTop = false

    @Published private(set) var postFeedViewModel: PostFeedViewModel?
    var thisUserProfileId: String? {
        octopus.core.profileRepository.profile?.id
    }

    let octopus: OctopusSDK
    private var storage = [AnyCancellable]()
    private var feedStorage = [AnyCancellable]()
    private var relativeDateFormatter: RelativeDateTimeFormatter = {
        let relativeDateFormatter = RelativeDateTimeFormatter()
        relativeDateFormatter.dateTimeStyle = .numeric
        relativeDateFormatter.unitsStyle = .short

        return relativeDateFormatter
    }()

    private var feed: Feed<OctopusCore.Post>?

    init(octopus: OctopusSDK) {
        self.octopus = octopus

        $openCreatePost
            .removeDuplicates()
            .dropFirst()
            .sink { [unowned self] in
                // refresh automatically when the create post is dismissed
                guard !$0 else { return }
                refreshFeed(isManual: false)
                scrollToTop = true
            }.store(in: &storage)

        $openUserProfile
            .removeDuplicates()
            .dropFirst()
            .sink { [unowned self] in
                // refresh automatically when the user profile is dismissed
                guard !$0 else { return }
                refreshFeed(isManual: false)
            }.store(in: &storage)
    }

    func set(feed: Feed<Post>) {
        guard postFeedViewModel?.feed.id != feed.id else { return }
        postFeedViewModel = PostFeedViewModel(octopus: octopus, postFeed: feed, ensureConnected: { [weak self] in
            guard let self else { return false }
            return self.ensureConnected()
        })
    }

    func userProfileTapped() {
        guard ensureConnected() else { return }
        openUserProfile = true
    }

    func createPostTapped() {
        guard ensureConnected() else { return }
        openCreatePost = true
    }

    // TODO: Delete when router is fully used
    private func ensureConnected() -> Bool {
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

    func refresh() async {
        await postFeedViewModel?.refresh()
    }

    private func refreshFeed(isManual: Bool) {
        postFeedViewModel?.refreshFeed(isManual: isManual)
    }
}
