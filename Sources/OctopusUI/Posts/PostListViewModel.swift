//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus
import OctopusCore
import UIKit
import SwiftUI

@MainActor
class PostListViewModel: ObservableObject {
    @Published var scrollToTop = false

    @Published var authenticationAction: ConnectedActionReplacement?
    var authenticationActionBinding: Binding<ConnectedActionReplacement?> {
        Binding(
            get: { self.authenticationAction },
            set: { self.authenticationAction = $0 }
        )
    }

    @Published private(set) var postFeedViewModel: PostFeedViewModel?
    var thisUserProfileId: String? {
        octopus.core.profileRepository.profile?.id
    }

    let octopus: OctopusSDK
    let connectedActionChecker: ConnectedActionChecker

    private var storage = [AnyCancellable]()
    private var feedStorage = [AnyCancellable]()
    private var relativeDateFormatter: RelativeDateTimeFormatter = {
        let relativeDateFormatter = RelativeDateTimeFormatter()
        relativeDateFormatter.dateTimeStyle = .numeric
        relativeDateFormatter.unitsStyle = .short

        return relativeDateFormatter
    }()

    private var feed: Feed<Post, Comment>?

    init(octopus: OctopusSDK, mainFlowPath: MainFlowPath) {
        self.octopus = octopus
        connectedActionChecker = ConnectedActionChecker(octopus: octopus)

        mainFlowPath.$path
            .prepend([])
            .zip(mainFlowPath.$path.removeDuplicates())
            .sink { [unowned self] previous, current in
                if case .currentUserProfile = previous.last, current == [] {
                    // refresh automatically when the user profile is dismissed
                    refreshFeed(isManual: false)
                    refreshCurrentUserProfile()
                } else if case .createPost = previous.last, current == [] {
                    refreshFeed(isManual: false)
                    scrollToTop = true
                }
            }.store(in: &storage)

        /// Reload current profile when app moves to foreground
        NotificationCenter.default
            .publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [unowned self] _ in
                refreshCurrentUserProfile()
            }
            .store(in: &storage)
    }

    func set(feed: Feed<Post, Comment>) {
        guard postFeedViewModel?.feed.id != feed.id else { return }
        postFeedViewModel = PostFeedViewModel(octopus: octopus, postFeed: feed, ensureConnected: { [weak self] action in
            guard let self else { return false }
            return self.ensureConnected(action: action)
        })
    }

    func ensureConnected(action: UserAction) -> Bool {
        connectedActionChecker.ensureConnected(action: action, actionWhenNotConnected: authenticationActionBinding)
    }

    func refresh() async {
        await withTaskGroup(of: Void.self) { group in
            let profileRepository = octopus.core.profileRepository
            group.addTask { [self] in await postFeedViewModel?.refresh() }
            group.addTask { try? await profileRepository.fetchCurrentUserProfile() }

            await group.waitForAll()
        }
    }

    private func refreshCurrentUserProfile() {
        let profileRepository = octopus.core.profileRepository
        Task { try? await profileRepository.fetchCurrentUserProfile() }
    }

    private func refreshFeed(isManual: Bool) {
        postFeedViewModel?.refreshFeed(isManual: isManual)
    }
}
