//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import Combine
@testable import OctopusUI
@testable import OctopusCore

@Suite
@MainActor
class GamificationRulesViewManagerTests {

    private static let viewCountKey = "OctopusSDK.UI.GamificationRulesViewManager.viewCount"
    private static let rulesDisplayedOnceKey = "OctopusSDK.UI.GamificationRulesViewManager.rulesDisplayedOnce"

    private func resetDefaults() {
        UserDefaults.standard.removeObject(forKey: Self.viewCountKey)
        UserDefaults.standard.removeObject(forKey: Self.rulesDisplayedOnceKey)
    }

    private func makeManager(gamificationEnabled: Bool) -> GamificationRulesViewManager {
        let config: GamificationConfig? = gamificationEnabled
            ? GamificationConfig(pointsName: "Points", abbrevPointSingular: "pt", abbrevPointPlural: "pts",
                                 pointsByAction: [:], gamificationLevels: [])
            : nil
        return GamificationRulesViewManager(
            gamificationConfigPublisher: Just(config).eraseToAnyPublisher())
    }

    /// The reported bug: the rules sheet was triggered even when the home screen was not on screen
    /// (e.g. preloaded in a background SwiftUI TabView tab), leaking onto the host app.
    @Test func doesNotTriggerWhenHomeScreenNotVisible_evenWhenAllOtherConditionsAreMet() {
        resetDefaults()
        let manager = makeManager(gamificationEnabled: true)

        // Reach the view-count threshold without ever marking the home screen as visible.
        manager.incrementViewCountIfNeeded()
        manager.incrementViewCountIfNeeded()
        manager.incrementViewCountIfNeeded()

        #expect(manager.shouldDisplayGamificationRules == false)
    }

    @Test func triggersWhenHomeScreenVisibleAndConditionsMet() {
        resetDefaults()
        let manager = makeManager(gamificationEnabled: true)
        manager.setHomeScreenVisible(true)

        manager.incrementViewCountIfNeeded()
        manager.incrementViewCountIfNeeded()
        manager.incrementViewCountIfNeeded()

        #expect(manager.shouldDisplayGamificationRules == true)
    }

    @Test func becomingVisibleAfterConditionsMet_triggersTheSheet() {
        resetDefaults()
        let manager = makeManager(gamificationEnabled: true)

        // Conditions reached while not visible -> must stay hidden.
        manager.incrementViewCountIfNeeded()
        manager.incrementViewCountIfNeeded()
        manager.incrementViewCountIfNeeded()
        #expect(manager.shouldDisplayGamificationRules == false)

        // Becoming visible re-evaluates and now triggers.
        manager.setHomeScreenVisible(true)
        #expect(manager.shouldDisplayGamificationRules == true)
    }

    @Test func doesNotTriggerWhenGamificationDisabled() {
        resetDefaults()
        let manager = makeManager(gamificationEnabled: false)
        manager.setHomeScreenVisible(true)

        manager.incrementViewCountIfNeeded()
        manager.incrementViewCountIfNeeded()
        manager.incrementViewCountIfNeeded()

        #expect(manager.shouldDisplayGamificationRules == false)
    }
}
