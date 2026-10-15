//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
@testable import OctopusUI

struct ResponseScrollAnchorTests {

    @Test func anchorDependsOnlyOnTheContent() {
        #expect(ResponseKind.comment.scrollAnchorId(for: "id") == ResponseKind.comment.scrollAnchorId(for: "id"))
        #expect(ResponseKind.comment.scrollAnchorId(for: "id") != ResponseKind.comment.scrollAnchorId(for: "other"))
    }

    @Test func commentAndReplyAnchorsNeverCollide() {
        #expect(ResponseKind.comment.scrollAnchorId(for: "id") != ResponseKind.reply.scrollAnchorId(for: "id"))
    }
}
