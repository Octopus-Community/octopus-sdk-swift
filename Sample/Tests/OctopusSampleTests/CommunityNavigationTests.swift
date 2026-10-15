//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import XCTest
import Combine
@testable import OctopusSample

/// The Community navigation setting and the router behaviour it drives, mirroring the Android sample's
/// `CommunityNavigationConfigTest`, `CommunityNavigationTest` and `CommunityTabReloadTest`.
@MainActor
final class CommunityNavigationTests: XCTestCase {
    private var storage = [AnyCancellable]()
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "CommunityNavigationTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        storage.removeAll()
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    // MARK: - Setting

    func testAConfigWithoutTheSettingOpensInTheTab() {
        XCTAssertEqual(CommunityNavigationManager(defaults: defaults).mode, .inTab)
    }

    func testAnUnknownStoredValueFallsBackToInTab() {
        defaults.set("sideBySide", forKey: CommunityNavigationManager.storageKey)
        XCTAssertEqual(CommunityNavigationManager(defaults: defaults).mode, .inTab)
    }

    func testTheChoiceIsPersisted() {
        CommunityNavigationManager(defaults: defaults).mode = .fullScreen
        XCTAssertEqual(CommunityNavigationManager(defaults: defaults).mode, .fullScreen)
    }

    // MARK: - In tab

    func testSelectingCommunityAgainGoesBackToTheFeed() {
        let (router, _) = makeRouter()
        router.select(.community)
        let stack = router.communityStackID

        router.select(.community)

        XCTAssertNotEqual(router.communityStackID, stack)
        XCTAssertFalse(router.isCommunityFullScreenPresented)
    }

    func testComingBackToCommunityFromAnotherTabKeepsItsScreens() {
        let (router, _) = makeRouter()
        router.select(.community)
        router.select(.settings)
        let stack = router.communityStackID

        router.select(.community)

        XCTAssertEqual(router.communityStackID, stack)
        XCTAssertEqual(router.selectedTab, .community)
    }

    func testInTabPushSelectsCommunityAndDeliversThePayload() {
        let (router, _) = makeRouter()
        var dismissals = 0
        router.dismissPresentations.sink { dismissals += 1 }.store(in: &storage)

        router.routeNotification(userInfo: ["octopus": "post-1"])

        XCTAssertEqual(dismissals, 1)
        XCTAssertEqual(router.selectedTab, .community)
        XCTAssertEqual(router.pendingNotificationUserInfo?["octopus"] as? String, "post-1")
        XCTAssertFalse(router.isCommunityFullScreenPresented)
    }

    // MARK: - Resets

    func testAModeChangeClosesTheCommunityAndStartsItOnTheFeed() {
        let (router, navigation) = makeRouter(mode: .fullScreen)
        router.presentCommunityFullScreen()
        let stack = router.communityStackID

        navigation.mode = .inTab

        XCTAssertFalse(router.isCommunityFullScreenPresented)
        XCTAssertNotEqual(router.communityStackID, stack)
    }

    func testSettingTheSameModeAgainKeepsTheCommunity() {
        let (router, navigation) = makeRouter()
        let stack = router.communityStackID

        navigation.mode = .inTab

        XCTAssertEqual(router.communityStackID, stack)
    }

    func testACommunitySwitchStartsTheCommunityOnTheFeed() {
        let switches = PassthroughSubject<Void, Never>()
        let (router, _) = makeRouter(mode: .fullScreen, communitySwitches: switches.eraseToAnyPublisher())
        router.presentCommunityFullScreen()
        let stack = router.communityStackID
        let reset = expectation(description: "community reset")
        router.$communityStackID.dropFirst().sink { _ in reset.fulfill() }.store(in: &storage)

        switches.send()

        wait(for: [reset], timeout: 2)
        XCTAssertNotEqual(router.communityStackID, stack)
        XCTAssertFalse(router.isCommunityFullScreenPresented)
    }

    // MARK: - Full screen

    func testFullScreenTabSelectionPresentsTheCommunityAboveTheTabs() {
        let (router, _) = makeRouter(mode: .fullScreen)

        router.select(.community)

        XCTAssertEqual(router.selectedTab, .community)
        XCTAssertTrue(router.isCommunityFullScreenPresented)
    }

    func testFullScreenPushPresentsTheCommunityAndKeepsTheCurrentTab() {
        let (router, _) = makeRouter(mode: .fullScreen)
        router.select(.settings)
        var dismissals = 0
        router.dismissPresentations.sink { dismissals += 1 }.store(in: &storage)

        router.routeNotification(userInfo: ["octopus": "post-1"])

        XCTAssertEqual(dismissals, 1)
        XCTAssertEqual(router.selectedTab, .settings)
        XCTAssertEqual(router.pendingNotificationUserInfo?["octopus"] as? String, "post-1")
        XCTAssertTrue(router.isCommunityFullScreenPresented)
    }

    func testFullScreenPushWaitsForAnOpenModalToClose() {
        var deferred = [(Bool) -> Void]()
        let (router, _) = makeRouter(
            mode: .fullScreen,
            hasOpenPresentation: { true },
            waitForDismissal: { deferred.append($0) }
        )

        router.routeNotification(userInfo: ["octopus": "post-1"])

        XCTAssertFalse(router.isCommunityFullScreenPresented)
        XCTAssertEqual(deferred.count, 1)
        deferred.forEach { $0(true) }
        XCTAssertTrue(router.isCommunityFullScreenPresented)
        XCTAssertEqual(router.pendingNotificationUserInfo?["octopus"] as? String, "post-1")
    }

    func testAModalThatStaysOpenKeepsThePushPendingWithoutPresenting() {
        var deferred = [(Bool) -> Void]()
        let (router, _) = makeRouter(
            mode: .fullScreen,
            hasOpenPresentation: { true },
            waitForDismissal: { deferred.append($0) }
        )
        router.routeNotification(userInfo: ["octopus": "post-1"])

        deferred.forEach { $0(false) }

        XCTAssertFalse(router.isCommunityFullScreenPresented, "never presents over a modal still on screen")
        XCTAssertEqual(router.pendingNotificationUserInfo?["octopus"] as? String, "post-1")
        router.presentCommunityFullScreen()
        XCTAssertTrue(router.isCommunityFullScreenPresented)
        XCTAssertEqual(router.pendingNotificationUserInfo?["octopus"] as? String, "post-1")
    }

    func testADeferredPresentationIsDroppedByAModeChange() {
        var deferred = [(Bool) -> Void]()
        let (router, navigation) = makeRouter(
            mode: .fullScreen,
            hasOpenPresentation: { true },
            waitForDismissal: { deferred.append($0) }
        )
        router.routeNotification(userInfo: ["octopus": "post-1"])

        navigation.mode = .inTab
        deferred.forEach { $0(true) }

        XCTAssertFalse(router.isCommunityFullScreenPresented)
        XCTAssertNil(router.pendingNotificationUserInfo)
    }

    func testADeferredPresentationIsDroppedByACommunitySwitch() {
        let switches = PassthroughSubject<Void, Never>()
        var deferred = [(Bool) -> Void]()
        let (router, _) = makeRouter(
            mode: .fullScreen,
            communitySwitches: switches.eraseToAnyPublisher(),
            hasOpenPresentation: { true },
            waitForDismissal: { deferred.append($0) }
        )
        router.routeNotification(userInfo: ["octopus": "post-1"])
        let reset = expectation(description: "community reset")
        router.$communityStackID.dropFirst().sink { _ in reset.fulfill() }.store(in: &storage)

        switches.send()
        wait(for: [reset], timeout: 2)
        deferred.forEach { $0(true) }

        XCTAssertFalse(router.isCommunityFullScreenPresented)
        XCTAssertNil(router.pendingNotificationUserInfo)
    }

    func testOnlyTheLatestDeferredPushPresents() {
        var deferred = [(Bool) -> Void]()
        var hasModal = true
        let (router, _) = makeRouter(
            mode: .fullScreen,
            hasOpenPresentation: { hasModal },
            waitForDismissal: { deferred.append($0) }
        )
        router.routeNotification(userInfo: ["octopus": "post-1"])
        router.routeNotification(userInfo: ["octopus": "post-2"])
        hasModal = false

        deferred[0](true)
        XCTAssertFalse(router.isCommunityFullScreenPresented, "a superseded deferral does not present")
        deferred[1](true)
        XCTAssertTrue(router.isCommunityFullScreenPresented)
        XCTAssertEqual(router.pendingNotificationUserInfo?["octopus"] as? String, "post-2")
    }

    func testFullScreenPushWhileTheCommunityIsUpHandsItThePayload() {
        var deferred = [(Bool) -> Void]()
        let (router, _) = makeRouter(
            mode: .fullScreen,
            hasOpenPresentation: { true },
            waitForDismissal: { deferred.append($0) }
        )
        router.presentCommunityFullScreen()
        var presentations = [Bool]()
        router.$isCommunityFullScreenPresented.dropFirst().sink { presentations.append($0) }.store(in: &storage)

        router.routeNotification(userInfo: ["octopus": "post-2"])

        XCTAssertTrue(deferred.isEmpty)
        XCTAssertTrue(presentations.isEmpty, "the presented community is neither closed nor presented again")
        XCTAssertEqual(router.pendingNotificationUserInfo?["octopus"] as? String, "post-2")
    }

    // MARK: - Helpers

    private func makeRouter(
        mode: CommunityNavigation = .inTab,
        communitySwitches: AnyPublisher<Void, Never> = Empty().eraseToAnyPublisher(),
        hasOpenPresentation: @escaping () -> Bool = { false },
        waitForDismissal: @escaping (@escaping (Bool) -> Void) -> Void = { $0(true) }
    ) -> (SampleTabRouter, CommunityNavigationManager) {
        let navigation = CommunityNavigationManager(defaults: defaults)
        navigation.mode = mode
        let router = SampleTabRouter(
            navigation: navigation,
            communitySwitches: communitySwitches,
            hasOpenPresentation: hasOpenPresentation,
            waitForDismissal: waitForDismissal
        )
        return (router, navigation)
    }
}
