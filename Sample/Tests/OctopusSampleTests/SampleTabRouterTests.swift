//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import XCTest
import Combine
@testable import OctopusSample

@MainActor
final class SampleTabRouterTests: XCTestCase {
    private var storage = [AnyCancellable]()
    private let suiteName = "SampleTabRouterTests"

    override func tearDown() {
        storage.removeAll()
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    /// A router on an isolated store, in the default In tab mode, whatever the tester picked in the app.
    private func makeRouter() -> SampleTabRouter {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        return SampleTabRouter(
            navigation: CommunityNavigationManager(defaults: defaults),
            communitySwitches: Empty().eraseToAnyPublisher()
        )
    }

    func testStartsOnScenariosWithoutPendingPush() {
        let router = makeRouter()
        XCTAssertEqual(router.selectedTab, .scenarios)
        XCTAssertNil(router.pendingNotificationUserInfo)
    }

    func testRoutedPushClosesPresentationsBeforeSelectingCommunity() {
        let router = makeRouter()
        router.select(.settings)
        var tabsWhenDismissed = [SampleTab]()
        router.dismissPresentations
            .sink { tabsWhenDismissed.append(router.selectedTab) }
            .store(in: &storage)

        router.routeNotification(userInfo: ["octopus": "post-1"])

        // One dismissal, sent while the previous tab was still selected: the open scenario modal closes
        // first, then the shell shows Community.
        XCTAssertEqual(tabsWhenDismissed, [.settings])
        XCTAssertEqual(router.selectedTab, .community)
    }

    func testRoutedPushIsPublishedOnceAndClearable() {
        let router = makeRouter()
        var deliveries = [String]()
        router.$pendingNotificationUserInfo
            .compactMap { $0?["octopus"] as? String }
            .sink { deliveries.append($0) }
            .store(in: &storage)

        router.routeNotification(userInfo: ["octopus": "post-1"])
        // Stands in for the SDK, which resets its `notificationUserInfo` binding once the target screen is open.
        router.pendingNotificationUserInfo = nil

        XCTAssertEqual(deliveries, ["post-1"])
        XCTAssertNil(router.pendingNotificationUserInfo)
    }

    func testPlainTabSelectionDoesNotClosePresentations() {
        let router = makeRouter()
        var dismissals = 0
        router.dismissPresentations.sink { dismissals += 1 }.store(in: &storage)

        router.select(.community)

        XCTAssertEqual(dismissals, 0)
        XCTAssertNil(router.pendingNotificationUserInfo)
    }

    func testTabIdsMatchTheAndroidSample() {
        XCTAssertEqual(SampleTab.allCases.map(\.accessibilityId), ["scenarios-tab", "community-tab", "settings-tab"])
    }
}
