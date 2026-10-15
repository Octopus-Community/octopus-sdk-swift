//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusCore
@testable import OctopusUI

/// The block offered by the "Report sent" alert, driven through `ReportViewModel` with scripted SDK calls.
@MainActor
struct ReportViewModelBlockTests {
    /// Records the SDK calls the view model makes. A block can be held until `releaseBlock()` so that a
    /// second tap lands while the first block is still in flight.
    @MainActor
    private final class Recorder {
        private(set) var reportCount = 0
        private(set) var blockedProfileIds = [String]()
        var blockError: Error?
        var holdBlock = false
        private var heldBlocks = [CheckedContinuation<Void, Never>]()

        func report() { reportCount += 1 }

        func block(_ profileId: String) async throws {
            blockedProfileIds.append(profileId)
            if holdBlock {
                await withCheckedContinuation { heldBlocks.append($0) }
            }
            if let blockError { throw blockError }
        }

        func releaseBlock() {
            heldBlocks.forEach { $0.resume() }
            heldBlocks.removeAll()
        }
    }

    private func makeViewModel(_ context: ReportViewModel.Context, recorder: Recorder,
                               blockedProfileIds: [String] = []) -> ReportViewModel {
        ReportViewModel(context: context, dependencies: .init(
            report: { _, _ in recorder.report() },
            blockUser: { try await recorder.block($0) },
            currentUser: { (id: "me", blockedProfileIds: blockedProfileIds) }))
    }

    /// Reports, then waits for the "Report sent" alert.
    private func reportAndWait(_ viewModel: ReportViewModel, offering profileIdToBlock: String? = "author")
    async throws {
        viewModel.report(reasons: [.spamAndScams])
        try await waitUntil { viewModel.moderationSent }
        #expect(viewModel.profileIdToBlock == profileIdToBlock)
    }

    @Test func theAlertOffersTheCallSiteProfileUnlessAlreadyBlocked() async throws {
        let contexts: [(ReportViewModel.Context, [String], String?)] = [
            (.content(contentId: "post", blockableProfileId: "author"), [], "author"),
            (.profile(profileId: "author", blockableProfileId: "author"), [], "author"),
            // The call site found no blockable author: moderator, the viewer, anonymous or deleted author.
            (.content(contentId: "post", blockableProfileId: nil), [], nil),
            (.profile(profileId: "author", blockableProfileId: nil), [], nil),
            // An already-blocked profile can still be opened and reported.
            (.profile(profileId: "author", blockableProfileId: "author"), ["author"], nil),
        ]
        for (context, blockedProfileIds, expected) in contexts {
            let viewModel = makeViewModel(context, recorder: Recorder(), blockedProfileIds: blockedProfileIds)
            try await reportAndWait(viewModel, offering: expected)
        }
    }

    @Test func aDoubleTapOnBlockBlocksOnce() async throws {
        let recorder = Recorder()
        recorder.holdBlock = true
        let viewModel = makeViewModel(.content(contentId: "post", blockableProfileId: "author"), recorder: recorder)
        try await reportAndWait(viewModel)

        viewModel.blockProfile()
        viewModel.blockProfile()
        #expect(viewModel.moderationInProgress)
        try await waitUntil { !recorder.blockedProfileIds.isEmpty }
        viewModel.blockProfile()
        recorder.releaseBlock()
        try await waitUntil { viewModel.blockDone }

        #expect(recorder.blockedProfileIds == ["author"])
        #expect(!viewModel.moderationInProgress)
        // Blocking sends no other report.
        #expect(recorder.reportCount == 1)
    }

    @Test func aFailedBlockKeepsTheReportAndClosesAfterTheError() async throws {
        let recorder = Recorder()
        recorder.blockError = AuthenticatedActionError.noNetwork
        let viewModel = makeViewModel(.profile(profileId: "author", blockableProfileId: "author"), recorder: recorder)
        try await reportAndWait(viewModel)
        viewModel.blockProfile()
        try await waitUntil { viewModel.error != nil }

        #expect(!viewModel.blockDone)
        #expect(!viewModel.moderationInProgress)
        #expect(viewModel.closeAfterError)
        #expect(recorder.reportCount == 1)
    }

    /// Polls `condition` on the main actor, failing after `timeout` seconds.
    private func waitUntil(timeout: TimeInterval = 2, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else {
                Issue.record("Condition not met within \(timeout)s")
                return
            }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
    }
}
