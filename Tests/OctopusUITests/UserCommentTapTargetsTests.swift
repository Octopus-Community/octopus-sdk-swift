//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
@testable import OctopusUI

struct UserCommentTapTargetsTests {

    @Test func commentAimsAtItself() {
        let targets = UserCommentTapTargets(commentId: "comment", parentCommentId: nil)
        #expect(targets.topLevelCommentId == "comment")
    }

    @Test func replyAimsAtTheCommentItAnswers() {
        let targets = UserCommentTapTargets(commentId: "reply", parentCommentId: "parent")
        #expect(targets.topLevelCommentId == "parent")
    }
}
