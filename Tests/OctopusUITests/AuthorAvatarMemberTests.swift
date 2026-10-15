//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusCore
@testable import OctopusUI

struct AuthorAvatarMemberTests {
    static let picture = URL(string: "https://cdn.example.com/own.jpg")!
    static let image = DefaultAvatar.image(url: URL(string: "https://cdn.example.com/a1b2.jpg")!)

    @Test func aPictureIsDrawnAsAPicture() {
        #expect(Author.Avatar.member(pictureUrl: Self.picture, name: "Zoé", community: nil)
                == .image(url: Self.picture, name: "Zoé"))
    }

    @Test func withoutPictureTheCommunityDefaultIsCarried() {
        #expect(Author.Avatar.member(pictureUrl: nil, name: "Zoé", community: Self.image)
                == .defaultImage(name: "Zoé", community: Self.image))
    }

    @Test func withoutPictureNorDefaultTheAvatarIsComputed() {
        #expect(Author.Avatar.member(pictureUrl: nil, name: "Zoé", community: nil) == .defaultImage(name: "Zoé"))
    }

    @Test func anAuthorCarriesTheCommunityDefault() {
        let author = Author(profile: MinimalProfile(uuid: "p1", nickname: "Zoé", defaultAvatar: Self.image),
                            gamificationLevel: nil)
        #expect(author.avatar == .defaultImage(name: "Zoé", community: Self.image))
    }

    @Test func aTypedNicknameKeepsTheCommunityDefault() {
        #expect(Author.Avatar.typing(nickname: "Zo", colorSeed: "User-tr6I", community: Self.image)
                == .defaultImage(name: "Zo", colorSeed: "User-tr6I", community: Self.image))
    }
}
