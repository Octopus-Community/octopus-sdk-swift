//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusGrpcModels
@testable import OctopusCore

/// `Poll(from:)`: the options of a poll post, as received from the server or read from the database.
struct PollMappingTests {

    @Test func mapsTheOptionsInOrder() throws {
        let poll = try #require(Poll(from: Com_Octopuscommunity_Poll.with {
            $0.answers = [
                .with { $0.id = "OPTION_1"; $0.text = "Oui"; $0.translatedText = "Yes" },
                .with { $0.id = "OPTION_2"; $0.text = "No" }
            ]
        }))

        #expect(poll.options.map(\.id) == ["OPTION_1", "OPTION_2"])
        #expect(poll.options.map(\.text) == [
            TranslatableText(originalText: "Oui", originalLanguage: nil, translatedText: "Yes"),
            // An option the server did not translate has no translated text.
            TranslatableText(originalText: "No", originalLanguage: nil, translatedText: nil)
        ])
    }

    @Test func noAnswersOrNoOptionListIsNoPoll() {
        #expect(Poll(from: Com_Octopuscommunity_Poll()) == nil)
        #expect(Poll(from: nil as [PollOptionEntity]?) == nil)
    }
}
