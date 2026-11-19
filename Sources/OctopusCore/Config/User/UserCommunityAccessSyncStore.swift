//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

/// A store that can be read synchronously to get the access to the community of the previous launch: whether it
/// was granted and, when it was not, the kind of the reason. The database answers too late for a host app that
/// reads them right after the SDK is initialized.
///
/// Only the kind of the reason is kept: the message of the server and the details of a ban stay in the database.
class UserCommunityAccessSyncStore {
    private let userDefaults: UserDefaults

    private let hasAccessToCommunityKey = "OctopusSDK.UserConfig.hasAccessToCommunityKey"
    private let noAccessReasonKey = "OctopusSDK.UserConfig.noAccessReason"

    /// The access as it was stored when this store was created, `nil` when none was.
    let userConfig: UserConfig?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let hasAccessToCommunity = userDefaults.object(forKey: hasAccessToCommunityKey) as? Bool {
            // An access stored without its reason (by a previous version) is refused for a reason not known
            let reason = userDefaults.string(forKey: noAccessReasonKey)
                .flatMap { CommunityNoAccessReason(storedName: $0, banDetails: nil) }
            userConfig = UserConfig(canAccessCommunity: hasAccessToCommunity, accessDeniedMessage: nil,
                                    noAccessReason: reason)
        } else {
            userConfig = nil
        }
    }

    func set(_ userConfig: UserConfig) {
        userDefaults.set(userConfig.canAccessCommunity, forKey: hasAccessToCommunityKey)
        if let reason = userConfig.noAccessReason {
            userDefaults.set(reason.storedName, forKey: noAccessReasonKey)
        } else {
            userDefaults.removeObject(forKey: noAccessReasonKey)
        }
    }

    func clear() {
        userDefaults.removeObject(forKey: hasAccessToCommunityKey)
        userDefaults.removeObject(forKey: noAccessReasonKey)
    }
}
