//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusCore
@testable import OctopusUI

/// The answer the post, comment and group screens act on once their content vanished from the cache, which the
/// logout purge does to everything the previous session saw. Only an answer from the server that the content is
/// gone may show it as unavailable: a failed fetch says nothing about it.
@Suite
struct VanishedContentCheckTests {
    // MARK: - Fetching the content itself (post detail)

    @Test func aPostTheServerReturnsIsStillAvailable() {
        #expect(VanishedContentCheck(fetchError: nil) == .stillAvailable)
    }

    @Test func aPostTheServerDoesNotFindIsGone() {
        #expect(VanishedContentCheck(fetchError: .serverError(.notFound)) == .gone)
    }

    @Test func aPostFetchedOfflineIsNotGone() {
        #expect(VanishedContentCheck(fetchError: .noNetwork) == .unanswered(.noNetwork))
    }

    @Test func aPostFetchTheServerFailsIsNotGone() {
        #expect(VanishedContentCheck(fetchError: .serverError(.timeout)) == .unanswered(.other))
        #expect(VanishedContentCheck(fetchError: .other(nil)) == .unanswered(.other))
    }

    // MARK: - Fetching the comment itself (comment detail, same answer as a post)

    /// The defect this locks: the comment screen read the purge as a deletion, showing "not available" and closing
    /// on a comment the next session can still read.
    @Test func aCommentTheServerReturnsIsStillAvailable() {
        #expect(VanishedContentCheck(fetchError: nil) == .stillAvailable)
    }

    @Test func aCommentTheServerDoesNotFindIsGone() {
        #expect(VanishedContentCheck(fetchError: .serverError(.notFound)) == .gone)
    }

    @Test func aCommentFetchedOfflineIsNotGone() {
        #expect(VanishedContentCheck(fetchError: .noNetwork) == .unanswered(.noNetwork))
    }

    // MARK: - Fetching the list that holds it (group detail)

    @Test func aGroupStillListedIsStillAvailable() {
        #expect(VanishedContentCheck(fetchedIds: .success(["a", "group"]), id: "group") == .stillAvailable)
    }

    @Test func aGroupMissingFromASuccessfulFetchIsGone() {
        #expect(VanishedContentCheck(fetchedIds: .success(["a"]), id: "group") == .gone)
    }

    /// The defect this locks: the group screen read a failed topics fetch as the group being deleted, because the
    /// fetch swallowed its error and left the cache — just purged — without the group.
    @Test func aGroupFetchedOfflineIsNotGone() {
        #expect(VanishedContentCheck(fetchedIds: .failure(.noNetwork), id: "group") == .unanswered(.noNetwork))
    }

    @Test func aGroupFetchTheServerFailsIsNotGone() {
        #expect(VanishedContentCheck(fetchedIds: .failure(.serverError(.timeout)), id: "group") == .unanswered(.other))
    }

    // MARK: - The event that makes the lists on screen load again (post feeds, profile comments)

    @Test func theLogoutPurgeClearsTheDisplayedContent() {
        #expect(InternalSdkEvent.userContentCleared.clearedDisplayedContent)
    }

    @Test(arguments: [InternalSdkEvent.profileUpdated, .groupFollowingChanged, .entitlementsChanged])
    func otherEventsDoNotClearTheDisplayedContent(event: InternalSdkEvent) {
        #expect(!event.clearedDisplayedContent)
    }

    // MARK: - What a detail screen does once the displayed content is cleared (post detail, comment detail)

    /// The defect this locks: a detail kept through a closure of the community, whose vanished check the closure
    /// blocked, stayed on its failure state after the reopening.
    @Test func aDetailLeftOnItsFailureAsksAgain() {
        #expect(VanishedContentCheck.asksAgainOnClearedContent(contentShown: false, loadFailure: .other))
        #expect(VanishedContentCheck.asksAgainOnClearedContent(contentShown: false, loadFailure: .noNetwork))
    }

    /// Without a failure, the vanished check the emptied cache started is still running, or answered.
    @Test func aDetailWithoutFailureDoesNotAskAgain() {
        #expect(!VanishedContentCheck.asksAgainOnClearedContent(contentShown: false, loadFailure: nil))
    }

    @Test func aDetailShowingItsContentDoesNotAskAgain() {
        #expect(!VanishedContentCheck.asksAgainOnClearedContent(contentShown: true, loadFailure: nil))
    }
}
