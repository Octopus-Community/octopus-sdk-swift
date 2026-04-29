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
    @Published var shouldDisplayGamificationRules = false
    @Published private(set) var gamificationConfig: GamificationConfig?

    @UserDefault(key: "OctopusSDK.UI.GamificationRulesViewManager.rulesDisplayedOnce", defaultValue: false)
    private(set) var rulesDisplayedOnce: Bool!

    @UserDefault(key: "OctopusSDK.UI.GamificationRulesViewManager.viewCount", defaultValue: 0)
    private var viewCount: Int!

    private var gamificationEnabled: Bool { gamificationConfig != nil }
    private var storage = [AnyCancellable]()

    /// Designated init. Accepts the gamification-config publisher directly so previews/tests can
    /// inject a fixed value without requiring a full `OctopusSDK`.
    init(gamificationConfigPublisher: AnyPublisher<GamificationConfig?, Never>) {
        gamificationConfigPublisher
            .sink { [unowned self] in
                gamificationConfig = $0
                updateShouldDisplayGamificationRules()
            }.store(in: &storage)
    }

    /// Production convenience.
    convenience init(octopus: OctopusSDK) {
        self.init(gamificationConfigPublisher:
            octopus.core.configRepository.communityConfigPublisher
                .map { $0?.gamificationConfig }
                .eraseToAnyPublisher())
    }

    /// Preview factory — no gamification config is ever emitted.
    static func forPreviews() -> GamificationRulesViewManager {
        GamificationRulesViewManager(
            gamificationConfigPublisher: Just<GamificationConfig?>(nil).eraseToAnyPublisher())
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
