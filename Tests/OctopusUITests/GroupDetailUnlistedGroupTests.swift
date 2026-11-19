//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
@testable import OctopusUI

/// What the group screen does with a group the groups list leaves out. The list only holds the groups the user may
/// see, while reading a group only takes the Access right: such a group is shown only when it can be read.
struct GroupDetailUnlistedGroupTests {
    @Test func aGroupTheUserCanAccessIsShown() {
        guard case .readable("group") = UnlistedGroupLookup(topic: "group", canAccess: true) else {
            Issue.record("expected the group to be readable")
            return
        }
    }

    @Test func aGroupTheUserCannotAccessIsNotAvailable() {
        guard case .notReadable = UnlistedGroupLookup(topic: "group", canAccess: false) else {
            Issue.record("expected the group to be not readable")
            return
        }
    }

    @Test func aMissingGroupIsNotAvailable() {
        guard case .notReadable = UnlistedGroupLookup<String>(topic: nil, canAccess: true) else {
            Issue.record("expected the group to be not readable")
            return
        }
    }
}
