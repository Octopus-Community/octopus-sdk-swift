//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import XCTest
import Combine
@testable import OctopusSample

@MainActor
final class CommunityTabBadgeViewModelTests: XCTestCase {
    private var storage = [AnyCancellable]()

    override func tearDown() {
        storage.removeAll()
        super.tearDown()
    }

    func testBadgeTextIsHiddenAtZeroAndCappedAbove99() {
        XCTAssertNil(CommunityTabBadgeViewModel.badgeText(for: 0))
        XCTAssertEqual(CommunityTabBadgeViewModel.badgeText(for: 1), "1")
        XCTAssertEqual(CommunityTabBadgeViewModel.badgeText(for: 99), "99")
        XCTAssertEqual(CommunityTabBadgeViewModel.badgeText(for: 100), "+99")
        XCTAssertNil(CommunityTabBadgeViewModel.badgeText(for: -1))
    }

    func testBadgeFollowsTheSdkCount() async {
        let count = CurrentValueSubject<Int, Never>(0)
        let viewModel = CommunityTabBadgeViewModel(
            countPublisher: { count.eraseToAnyPublisher() },
            communitySwitches: Empty().eraseToAnyPublisher())

        count.send(100)
        await waitForCount(100, on: viewModel)
        XCTAssertEqual(viewModel.badgeText, "+99")

        count.send(0)
        await waitForCount(0, on: viewModel)
        XCTAssertNil(viewModel.badgeText)
    }

    func testBadgeFollowsTheNewSdkAfterACommunitySwitch() async {
        let firstCommunity = CurrentValueSubject<Int, Never>(3)
        let secondCommunity = CurrentValueSubject<Int, Never>(1)
        var current = firstCommunity
        let switches = PassthroughSubject<Void, Never>()
        let viewModel = CommunityTabBadgeViewModel(
            countPublisher: { current.eraseToAnyPublisher() },
            communitySwitches: switches.eraseToAnyPublisher())
        await waitForCount(3, on: viewModel)

        current = secondCommunity
        switches.send()
        await waitForCount(1, on: viewModel)
        XCTAssertEqual(viewModel.badgeText, "1")

        // The previous SDK instance no longer drives the badge.
        var seen = [Int]()
        viewModel.$unreadCount.sink { seen.append($0) }.store(in: &storage)
        firstCommunity.send(42)
        secondCommunity.send(99)
        await waitForCount(99, on: viewModel)
        XCTAssertFalse(seen.contains(42))
        XCTAssertEqual(viewModel.badgeText, "99")
    }

    func testBadgeClearsWhenTheSwitchLeavesNoSdk() async {
        let count = CurrentValueSubject<Int, Never>(5)
        var hasSdk = true
        let switches = PassthroughSubject<Void, Never>()
        let viewModel = CommunityTabBadgeViewModel(
            countPublisher: { hasSdk ? count.eraseToAnyPublisher() : nil },
            communitySwitches: switches.eraseToAnyPublisher())
        await waitForCount(5, on: viewModel)

        hasSdk = false
        switches.send()
        await waitForCount(0, on: viewModel)
        XCTAssertNil(viewModel.badgeText)
    }

    private func waitForCount(_ expected: Int, on viewModel: CommunityTabBadgeViewModel) async {
        let reached = expectation(description: "unread count reaches \(expected)")
        viewModel.$unreadCount
            .first { $0 == expected }
            .sink { _ in reached.fulfill() }
            .store(in: &storage)
        await fulfillment(of: [reached], timeout: 2)
    }
}
