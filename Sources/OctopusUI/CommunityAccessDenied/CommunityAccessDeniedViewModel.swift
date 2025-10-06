//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus
import OctopusCore
import os

@MainActor
class CommunityAccessDeniedViewModel: ObservableObject {
    @Published private(set) var dismiss = false
    @Published private(set) var accessDeniedMessage: String?

    let octopus: OctopusSDK

    private var storage = [AnyCancellable]()

    init(octopus: OctopusSDK) {
        self.octopus = octopus

        octopus.core.configRepository.userConfigPublisher.sink { [unowned self] in
            if let userConfig = $0, !userConfig.canAccessCommunity {
                accessDeniedMessage = userConfig.accessDeniedMessage
            } else {
                dismiss = true
            }
        }.store(in: &storage)

        Task {
            do {
                try await octopus.core.configRepository.refreshCommunityAccess()
            } catch {
                if #available(iOS 14, *) { Logger.config.trace("Error while refreshing community access: \(error)") }
            }
        }
    }
}
