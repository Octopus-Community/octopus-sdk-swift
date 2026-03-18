//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusCore

@Suite
class ClientPostTests {
    @Test func hashClientPostWithNullValues() throws {
        let clientPost = ClientPost(
            clientObjectId: "a7dada1c-f933-4186-9e72-88927ef3bf90",
            topicId: nil,
            text: "Text here",
            catchPhrase: nil,
            attachment: nil,
            viewClientObjectButtonText: nil
        )

        try #expect(clientPost.getHashForSignature() == "44928831e861ca52f0ea8be57a394e9f966a1bc8b19709ad80bd033d1a833232")
    }

    @Test func hashClientPostWithRemoteImage() throws {
        let clientPost = ClientPost(
            clientObjectId: "a7dada1c-f933-4186-9e72-88927ef3bf90",
            topicId: nil,
            text: "Text here",
            catchPhrase: nil,
            attachment: .distantImage(URL(string: "https://media-content-dev.octocdn.net/sample_640%C3%97426.jpeg")!),
            viewClientObjectButtonText: "see item"
        )

        try #expect(clientPost.getHashForSignature() == "f3477a91dbf0948c3308df583d070647193b9bfcb08cc0281827204f5927bcb7")
    }

    @Test func hashClientPostWithLocalImage() throws {
        let imageUrl = try #require(Bundle.module.url(forResource: "clientPostImg1", withExtension: "png"))
        let imageData = try Data(contentsOf: imageUrl)
        let clientPost = ClientPost(
            clientObjectId: "ea2ebba8-c2d6-4945-95e7-1c2eafd97c2e",
            topicId: nil,
            text: "Text here",
            catchPhrase: "What do you think ?",
            attachment: .localImage(imageData),
            viewClientObjectButtonText: "see item"
        )

        try #expect(clientPost.getHashForSignature() == "8136cbd29dc13bdf22eeffccbe890d16910ff38ed865e1a70a520d668a675204")
    }

    @Test func hashClientPostWithTopic() throws {
        let imageUrl = try #require(Bundle.module.url(forResource: "clientPostImg2", withExtension: "jpeg"))
        let imageData = try Data(contentsOf: imageUrl)
        let clientPost = ClientPost(
            clientObjectId: "570c32e4-5179-44f1-9ed6-95b92ed885d6",
            topicId: "a1snSDVg0BRLQHZ-qKrdPS",
            text: "Text here",
            catchPhrase: "What do you think ?",
            attachment: .localImage(imageData),
            viewClientObjectButtonText: "see item"
        )

        try #expect(clientPost.getHashForSignature() == "3837e589f323ba0d701ce2d2a19fd4b559e4ba180f9932e5d32b583402da97be")
    }
}
