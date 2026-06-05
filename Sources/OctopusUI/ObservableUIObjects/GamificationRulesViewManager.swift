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
    /// Whether the home screen is currently on screen. The rules sheet must only ever be presented
    /// while the home screen is visible: otherwise it can be triggered (e.g. by the config arriving)
    /// while the SDK is preloaded in a background SwiftUI `TabView` tab, presenting the sheet over —
    /// and corrupting the layout of — the host app's currently visible screen.
    private var isHomeScreenVisible = false
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

    /// Called by the home screen when its visibility changes (`onAppear` / `onDisappear`).
    /// Becoming visible re-evaluates the conditions so a sheet whose conditions were met while
    /// the screen was off screen is presented as soon as the user actually opens the community.
    func setHomeScreenVisible(_ visible: Bool) {
        isHomeScreenVisible = visible
        if visible {
            updateShouldDisplayGamificationRules()
        }
    }

    func incrementViewCountIfNeeded() {
        if gamificationEnabled {
            viewCount += 1
            updateShouldDisplayGamificationRules()
        }
    }

    private func updateShouldDisplayGamificationRules() {
        if viewCount >= 3, !rulesDisplayedOnce, gamificationEnabled, isHomeScreenVisible {
            shouldDisplayGamificationRules = true
        }
    }
}
