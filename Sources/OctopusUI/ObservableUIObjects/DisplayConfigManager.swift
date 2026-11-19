//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus
import OctopusCore

@MainActor
final class DisplayConfigManager: ObservableObject {
    @Published private(set) var poweredByConfig: DisplayConfig.PoweredByOctopus = .normal
    /// The community's post options, read by the posts for their image and group name taps.
    @Published private(set) var postOptions: ContentOptions.PostOptions = ContentOptions.allEnabled.post

    /// Whether the member can access a group: `nil` when the group is not known locally.
    private let canAccessGroup: (_ groupId: String) -> Bool?
    /// The host app's group access denied callback.
    private let onGroupAccessDenied: (_ groupId: String) -> Void

    private var storage = [AnyCancellable]()

    /// Designated init. Accepts the publishers and the group access closures directly so previews/tests can
    /// inject fixed values without requiring a full `OctopusSDK`.
    init(poweredByPublisher: AnyPublisher<DisplayConfig.PoweredByOctopus, Never>,
         postOptionsPublisher: AnyPublisher<ContentOptions.PostOptions, Never> =
            Just(ContentOptions.allEnabled.post).eraseToAnyPublisher(),
         canAccessGroup: @escaping (_ groupId: String) -> Bool? = { _ in nil },
         onGroupAccessDenied: @escaping (_ groupId: String) -> Void = { _ in }) {
        self.canAccessGroup = canAccessGroup
        self.onGroupAccessDenied = onGroupAccessDenied
        poweredByPublisher
            .sink { [unowned self] in poweredByConfig = $0 }
            .store(in: &storage)
        postOptionsPublisher
            .removeDuplicates()
            .sink { [unowned self] in postOptions = $0 }
            .store(in: &storage)
    }

    /// Production convenience.
    convenience init(octopus: OctopusSDK) {
        let communityConfig = octopus.core.configRepository.communityConfigPublisher
        self.init(
            poweredByPublisher: communityConfig
                .map { $0?.displayConfig?.poweredByOctopus ?? .normal }
                .eraseToAnyPublisher(),
            postOptionsPublisher: communityConfig
                .map { ($0?.contentOptions ?? .allEnabled).post }
                .eraseToAnyPublisher(),
            canAccessGroup: { [weak octopus] groupId in
                octopus?.core.topicsRepository.topics.first { $0.uuid == groupId }?.permissions.canAccess
            },
            onGroupAccessDenied: { [weak octopus] groupId in
                octopus?.groupAccessDeniedCallback?(groupId)
            })
    }

    /// Opens a group from the group name of a post, the way the groups list does: a group the member cannot
    /// access calls the host app's ``OctopusSDK/groupAccessDeniedCallback`` instead of being opened. A group that
    /// is not known locally is opened, and its page handles the access.
    func openGroupFromPost(groupId: String, open: (_ groupId: String) -> Void) {
        if canAccessGroup(groupId) == false {
            onGroupAccessDenied(groupId)
        } else {
            open(groupId)
        }
    }

    /// Preview factory — emits `.normal` and never updates.
    static func forPreviews() -> DisplayConfigManager {
        DisplayConfigManager(poweredByPublisher: Just(.normal).eraseToAnyPublisher())
    }
}
