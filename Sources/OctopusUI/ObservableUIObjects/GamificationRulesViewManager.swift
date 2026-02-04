//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus
import OctopusCore

/// Object that manages whether the gamification rules should be automatically displayed
@MainActor
final class GamificationRulesViewManager: ObservableObject {
    private let octopus: OctopusSDK

    @Published var shouldDisplayGamificationRules = false
    @Published private(set) var gamificationConfig: GamificationConfig?

    @UserDefault(key: "OctopusSDK.UI.GamificationRulesViewManager.rulesDisplayedOnce", defaultValue: false)
    private(set) var rulesDisplayedOnce: Bool!

    @UserDefault(key: "OctopusSDK.UI.GamificationRulesViewManager.viewCount", defaultValue: 0)
    private var viewCount: Int!

    private var gamificationEnabled: Bool { gamificationConfig != nil }
    private var storage = [AnyCancellable]()

    init(octopus: OctopusSDK) {
        self.octopus = octopus

        octopus.core.configRepository.communityConfigPublisher
            .map { $0?.gamificationConfig }
            .sink { [unowned self] in
                gamificationConfig = $0
                updateShouldDisplayGamificationRules()
            }.store(in: &storage)
    }

    func gamificationRulesDisplayed() {
        rulesDisplayedOnce = true
    }

    func incrementViewCountIfNeeded() {
        if gamificationEnabled {
            viewCount += 1
            updateShouldDisplayGamificationRules()
        }
    }

    private func updateShouldDisplayGamificationRules() {
        if viewCount >= 3, !rulesDisplayedOnce, gamificationEnabled {
            shouldDisplayGamificationRules = true
        }
    }
}
