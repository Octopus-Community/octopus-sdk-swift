//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusGrpcModels
@testable import OctopusCore

struct DefaultAvatarTests {
    @Test func colorIsReadFromTheProto() {
        let proto = Com_Octopuscommunity_DefaultAvatar.with {
            $0.color = .with {
                $0.backgroundHex = "#3366CC"
                $0.initialsHex = "#FFFFFF"
            }
        }
        #expect(DefaultAvatar(from: proto) == .color(backgroundHex: "#3366CC", initialsHex: "#FFFFFF"))
    }

    @Test func imageIsReadFromTheProto() {
        let proto = Com_Octopuscommunity_DefaultAvatar.with { $0.imageURL = "https://cdn.example.com/a1b2.jpg" }
        #expect(DefaultAvatar(from: proto) == .image(url: URL(string: "https://cdn.example.com/a1b2.jpg")!))
    }

    @Test func aMessageWithoutKnownKindIsNil() {
        #expect(DefaultAvatar(from: Com_Octopuscommunity_DefaultAvatar()) == nil)
    }

    @Test(arguments: ["", "#FFF", "FFFFFF", "#GGGGGG", "#FFFFFFFF", "#FFFFF "])
    func anInvalidColorIsNil(hex: String) {
        let badBackground = Com_Octopuscommunity_DefaultAvatar.with {
            $0.color = .with {
                $0.backgroundHex = hex
                $0.initialsHex = "#000000"
            }
        }
        let badInitials = Com_Octopuscommunity_DefaultAvatar.with {
            $0.color = .with {
                $0.backgroundHex = "#3366CC"
                $0.initialsHex = hex
            }
        }
        #expect(DefaultAvatar(from: badBackground) == nil)
        #expect(DefaultAvatar(from: badInitials) == nil)
    }

    @Test func lowercaseHexIsAccepted() {
        #expect(DefaultAvatar(backgroundHex: "#3366cc", initialsHex: "#ffffff", imageUrl: nil)
                == .color(backgroundHex: "#3366cc", initialsHex: "#ffffff"))
    }

    @Test func fullwidthHexDigitsAreRejected() {
        // `Character.isHexDigit` accepts fullwidth digits; the server (and Android) only send ASCII
        #expect(DefaultAvatar(backgroundHex: "#\u{FF13}\u{FF13}66CC", initialsHex: "#FFFFFF", imageUrl: nil) == nil)
        #expect(DefaultAvatar(backgroundHex: "#3366CC", initialsHex: "#\u{FF13}\u{FF13}66CC", imageUrl: nil) == nil)
    }

    @Test(arguments: ["http://cdn.example.com/a1b2.jpg", "HTTPS://cdn.example.com/a1b2.jpg"])
    func anHttpOrUppercaseSchemeImageUrlIsAccepted(url: String) {
        let proto = Com_Octopuscommunity_DefaultAvatar.with { $0.imageURL = url }
        #expect(DefaultAvatar(from: proto) == .image(url: URL(string: url)!))
    }

    @Test(arguments: [
        "", "not a url", "ftp://cdn.example.com/a1b2.jpg", "/relative/a1b2.jpg", "https:///a1b2.jpg", "https:",
    ])
    func anInvalidImageUrlIsNil(url: String) {
        let proto = Com_Octopuscommunity_DefaultAvatar.with { $0.imageURL = url }
        #expect(DefaultAvatar(from: proto) == nil)
    }

    @Test(arguments: [
        DefaultAvatar.color(backgroundHex: "#3366CC", initialsHex: "#000000"),
        DefaultAvatar.image(url: URL(string: "https://cdn.example.com/a1b2.jpg")!),
    ])
    func theStoredFormRebuildsTheSameValue(avatar: DefaultAvatar) {
        #expect(DefaultAvatar(backgroundHex: avatar.backgroundHex, initialsHex: avatar.initialsHex,
                              imageUrl: avatar.imageUrl?.absoluteString) == avatar)
    }

    @Test func nothingStoredIsNil() {
        #expect(DefaultAvatar(backgroundHex: nil, initialsHex: nil, imageUrl: nil) == nil)
    }
}
