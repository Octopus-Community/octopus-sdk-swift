//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import Testing
@testable import OctopusUI

/// What the detail screens rely on to follow the newest response only while it is on screen, and to load older ones
/// only once their loader rests on screen: `tracksOnScreenPresence(as:when:)` read by
/// `onTrackedViewOnScreenChanged(of:settleDelay:perform:)`.
@Suite(.serialized)
@MainActor
struct OnScreenTrackingTests {
    @Test func reportsTheTrackedViewOnScreenThenScrolledOff() async throws {
        let list = TrackedList(isTracked: true)

        try await renderInWindow(
            TrackedListHost(list: list),
            until: { list.reports == [true] },
            andThen: {
                list.heightAbove = 5000
                try await waitUntil { list.reports == [true, false] }
                list.heightAbove = 0
                try await waitUntil { list.reports == [true, false, true] }
            })

        #expect(list.reports == [true, false, true])
    }

    @Test func reportsNothingWhileTheViewIsNotTracked() async throws {
        let list = TrackedList(isTracked: false)

        // The loader above, tracked under another role, is on screen too: once it is reported, so would the row be.
        try await renderInWindow(TrackedListHost(list: list), until: { list.loaderReports == [true] })

        #expect(list.reports.isEmpty)
    }

    // The newest row of a list passes the role to the next one: the one it leaves reports off screen.
    @Test func aViewNoLongerTrackedCountsAsOffScreen() async throws {
        let list = TrackedList(isTracked: true)

        try await renderInWindow(
            TrackedListHost(list: list),
            until: { list.reports == [true] },
            andThen: {
                list.isTracked = false
                try await waitUntil { list.reports == [true, false] }
                list.isTracked = true
                try await waitUntil { list.reports == [true, false, true] }
            })

        #expect(list.reports == [true, false, true])
    }

    // The loader of older items shows during a scroll, or for the single frame of a scroll made while the scroll view
    // bounces at its top: it must not load a page.
    @Test func reportsNothingForAViewThatCrossesTheScreen() async throws {
        let list = TrackedList(isTracked: true, heightAbove: 5000)

        try await renderInWindow(
            TrackedListHost(list: list, settleDelay: Self.longSettleDelay),
            until: { list.loaderReports == [true] },
            andThen: {
                list.heightAbove = 0
                try await Task.sleep(nanoseconds: 50_000_000)
                list.heightAbove = 5000
                try await Task.sleep(nanoseconds: 2 * Self.longSettleDelayNanoseconds)
            })

        #expect(list.reports.isEmpty)
    }

    // A scroll made while the scroll view bounces at its top can move the loader away for a single frame: the scroll
    // keeping a response in place did not take.
    @Test func keepsReportingOnScreenAViewThatLeavesForAMoment() async throws {
        let list = TrackedList(isTracked: true)

        try await renderInWindow(
            TrackedListHost(list: list, settleDelay: Self.longSettleDelay),
            until: { list.reports == [true] },
            andThen: {
                list.heightAbove = 5000
                try await Task.sleep(nanoseconds: 50_000_000)
                list.heightAbove = 0
                try await Task.sleep(nanoseconds: 2 * Self.longSettleDelayNanoseconds)
            })

        #expect(!list.reports.contains(false))
    }

    // The screen tells the loader rested on screen again after the scroll keeping a response in place was lost.
    @Test func reportsTheViewAgainEachTimeItComesToRestOnScreen() async throws {
        let list = TrackedList(isTracked: true)

        try await renderInWindow(
            TrackedListHost(list: list),
            until: { list.reports == [true] },
            andThen: {
                list.heightAbove = 10
                try await waitUntil { list.reports == [true, true] }
            })

        #expect(list.reports == [true, true])
    }

    private static let longSettleDelay: TimeInterval = 0.5
    private static let longSettleDelayNanoseconds = UInt64(longSettleDelay * 1_000_000_000)
}

@MainActor
private final class TrackedList: ObservableObject {
    @Published var isTracked: Bool
    @Published var heightAbove: CGFloat
    var reports: [Bool] = []
    var loaderReports: [Bool] = []

    init(isTracked: Bool, heightAbove: CGFloat = 0) {
        self.isTracked = isTracked
        self.heightAbove = heightAbove
    }
}

/// A scroll view whose tracked row is pushed below the screen by the height above it, under a loader tracked with
/// another role that stays on screen, as in the detail screens.
private struct TrackedListHost: View {
    @ObservedObject var list: TrackedList
    var settleDelay: TimeInterval = 0.1

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Color.gray.frame(height: 20)
                    .tracksOnScreenPresence(as: .olderItemsLoader)
                Color.clear.frame(height: list.heightAbove)
                Color.blue.frame(height: 50)
                    .tracksOnScreenPresence(as: .newestItem, when: list.isTracked)
            }
        }
        .onTrackedViewOnScreenChanged(of: .newestItem, settleDelay: settleDelay) { list.reports.append($0) }
        .onTrackedViewOnScreenChanged(of: .olderItemsLoader, settleDelay: settleDelay) { list.loaderReports.append($0) }
    }
}
