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
    @Published private(set) var overridenLocale: Locale?

    let octopus: OctopusSDK
    private var storage = [AnyCancellable]()

    init(octopus: OctopusSDK) {
        self.octopus = octopus

        octopus.core.configRepository.userConfigPublisher.sink { [unowned self] userConfig in
            guard userConfig?.canAccessCommunity ?? true else {
                displayOnboarding = false
                displayCommunityAccessDenied = true
                return
            }
            displayCommunityAccessDenied = false
        }.store(in: &storage)

        octopus.core.languageRepository.$overridenLocale.sink { [unowned self] in
            overridenLocale = $0
        }.store(in: &storage)
    }
}
