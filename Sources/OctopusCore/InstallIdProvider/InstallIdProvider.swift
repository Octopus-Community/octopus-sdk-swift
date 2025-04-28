//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

/// Class that provides an installation id. This id is kept until the app is deleted.
class InstallIdProvider {
    @UserDefault(key: "OctopusSDK.InstallId") private(set) var installId: String!
    private(set) var isNewInstall = false

    init() {
        if installId == nil {
            isNewInstall = true
            installId = UUID().uuidString
        }
    }
}
