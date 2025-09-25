//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus
import OctopusCore

@MainActor
class CommunityAccessDeniedViewModel: ObservableObject {
    @Published private(set) var dismiss = false
    @Published private(set) var accessDeniedMessage: String?

    let octopus: OctopusSDK

    private var storage = [AnyCancellable]()

    init(octopus: OctopusSDK) {
        self.octopus = octopus

        if let userConfig = octopus.core.configRepository.userConfig, !userConfig.canAccessCommunity {
            accessDeniedMessage = userConfig.accessDeniedMessage
        } else {
            dismiss = true
        }

    }
}
