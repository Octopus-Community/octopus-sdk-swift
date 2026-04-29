//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import XCTest
import OctopusCore
@testable import OctopusUI

final class AuthorCanBeBlockedTests: XCTestCase {
    func test_canBeBlocked_deletedAuthor_returnsFalse() {
        let author = makeAuthor(profileId: nil, tags: [])
        XCTAssertFalse(author.canBeBlocked(currentUserId: "me"))
        XCTAssertFalse(author.canBeBlocked(currentUserId: nil))
    }

    func test_canBeBlocked_adminAuthor_returnsFalse() {
        let author = makeAuthor(profileId: "admin", tags: .admin)
        XCTAssertFalse(author.canBeBlocked(currentUserId: "me"))
    }

    func test_canBeBlocked_selfAuthor_returnsFalse() {
        let author = makeAuthor(profileId: "me", tags: [])
        XCTAssertFalse(author.canBeBlocked(currentUserId: "me"))
    }

    func test_canBeBlocked_otherNonAdminAuthor_returnsTrue() {
        let author = makeAuthor(profileId: "someone", tags: [])
        XCTAssertTrue(author.canBeBlocked(currentUserId: "me"))
        XCTAssertTrue(author.canBeBlocked(currentUserId: nil))
    }

    private func makeAuthor(profileId: String?, tags: ProfileTags) -> Author {
        Author(
            profileId: profileId,
            avatar: .notConnected,
            name: .localizedString(""),
            tags: tags,
            gamificationLevel: nil)
    }
}
