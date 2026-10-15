//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
@testable import OctopusUI

struct AuthorAvatarColorTests {
    @Test func typedNicknameKeepsTheStoredNicknameColor() {
        #expect(Author.Avatar.typing(nickname: "Zoé", colorSeed: "User-tr6I")
                == .defaultImage(name: "Zoé", colorSeed: "User-tr6I"))
        #expect(Author.Avatar.colorSource(name: "Zoé", colorSeed: "User-tr6I") == "User-tr6I")
    }

    @Test func emptyNicknameShowsTheSilhouette() {
        #expect(Author.Avatar.typing(nickname: "", colorSeed: "User-tr6I") == .notConnected)
    }

    @Test(arguments: [nil, ""] as [String?])
    func withoutSeedTheColorFollowsTheName(colorSeed: String?) {
        #expect(Author.Avatar.colorSource(name: "Zoé", colorSeed: colorSeed) == "Zoé")
    }
}
