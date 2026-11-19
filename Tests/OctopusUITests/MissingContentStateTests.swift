//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusCore
@testable import OctopusUI

/// What the comment screen shows once its comment is missing, which the logout purge causes on every comment on
/// display. The defect these lock: the screen showed "not available" for any missing comment, while it was still
/// asking the server and after an offline answer, for a comment the next session can still read.
@Suite
struct MissingContentStateTests {
    /// The comment vanished from the cache and the server has not answered yet, or the screen opens on a comment
    /// that is not cached.
    @Test func aPendingCheckShowsTheLoader() {
        #expect(missingContentState(notAvailable: false, loadFailure: nil) == .loader)
    }

    @Test func anOfflineCheckShowsTheOfflineFailureWithItsRetry() {
        let failure = vanishedContentFailure(.noNetwork)
        #expect(missingContentState(notAvailable: false, loadFailure: failure) == .failure(.noNetwork))
    }

    @Test func aCheckTheServerFailsShowsTheGenericFailure() {
        let failure = vanishedContentFailure(.serverError(.timeout))
        #expect(missingContentState(notAvailable: false, loadFailure: failure) == .failure(.other))
    }

    @Test func aCommentTheServerDoesNotFindShowsNotAvailable() {
        #expect(VanishedContentCheck(fetchError: .serverError(.notFound)) == .gone)
        #expect(missingContentState(notAvailable: true, loadFailure: nil) == .notAvailable)
    }

    /// An offline check, then a retry the server answers with "not found".
    @Test func theServerAnswerWinsOverAnEarlierFailure() {
        #expect(missingContentState(notAvailable: true, loadFailure: .noNetwork) == .notAvailable)
    }

    /// The failure the screen keeps from the check, as `CommentDetailViewModel` stores it.
    private func vanishedContentFailure(_ error: ServerCallError) -> ScreenStateFailure? {
        guard case let .unanswered(failure) = VanishedContentCheck(fetchError: error) else { return nil }
        return failure
    }
}
