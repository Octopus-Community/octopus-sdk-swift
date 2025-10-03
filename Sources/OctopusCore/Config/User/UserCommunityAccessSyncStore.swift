//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

/// A store that can be read synchronously to get the value of `hasAccessToCommunity`.
class UserCommunityAccessSyncStore {
    private let userDefaults = UserDefaults.standard

    private let hasAccessToCommunityKey = "OctopusSDK.UserConfig.hasAccessToCommunityKey"
    private(set) var hasAccessToCommunity: Bool?

    init() {
        hasAccessToCommunity = userDefaults.object(forKey: hasAccessToCommunityKey) as? Bool
    }

    func set(hasAccessToCommunity: Bool) {
        userDefaults.set(hasAccessToCommunity, forKey: hasAccessToCommunityKey)
    }
}
