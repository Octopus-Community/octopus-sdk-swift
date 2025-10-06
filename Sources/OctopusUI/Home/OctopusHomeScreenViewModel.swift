//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus
import OctopusCore
import os

@MainActor
class OctopusHomeScreenViewModel: ObservableObject {

    @Published private(set) var mainFlowPath = MainFlowPath()
    @Published private(set) var displayOnboarding = false
    @Published private(set) var displayCommunityAccessDenied = false

    let octopus: OctopusSDK
    private var storage = [AnyCancellable]()

    init(octopus: OctopusSDK) {
        self.octopus = octopus

        Publishers.CombineLatest3(
            octopus.core.profileRepository.profilePublisher,
            octopus.core.configRepository.userConfigPublisher,
            mainFlowPath.$isLocked
        ).sink { [unowned self] profile, userConfig, isLocked in
            guard !isLocked else { return }
            guard userConfig?.canAccessCommunity ?? true else {
                displayOnboarding = false
                displayCommunityAccessDenied = true
                return
            }
            displayCommunityAccessDenied = false
            if let profile, !profile.hasSeenOnboarding {
                displayOnboarding = true
            } else {
                displayOnboarding = false
            }
        }.store(in: &storage)
    }
}
