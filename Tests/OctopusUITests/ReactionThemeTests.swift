//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
import UIKit
@testable import OctopusUI
@testable import OctopusCore

@Suite
@MainActor
class ReactionThemeTests {

    @Test func defaultInitReturnsNonNilImages() {
        let reaction = OctopusTheme.Assets.Icons.Content.Reaction()
        #expect(reaction.heart.size.width > 0)
        #expect(reaction.joy.size.width > 0)
        #expect(reaction.mouthOpen.size.width > 0)
        #expect(reaction.clap.size.width > 0)
        #expect(reaction.cry.size.width > 0)
        #expect(reaction.rage.size.width > 0)
    }

    @Test func partialOverrideReturnsCustomImage() {
        let custom = UIImage(systemName: "star.fill")!
        let reaction = OctopusTheme.Assets.Icons.Content.Reaction(heart: custom)
        #expect(reaction.heart === custom)
        // Others remain SDK defaults (non-nil, but not our custom image)
        #expect(reaction.joy !== custom)
        #expect(reaction.joy.size.width > 0)
    }

    @Test func subscriptReturnsCorrectImage() {
        let custom = UIImage(systemName: "star.fill")!
        let reaction = OctopusTheme.Assets.Icons.Content.Reaction(clap: custom)
        #expect(reaction[.clap] === custom)
        #expect(reaction[.heart] !== custom)
    }

    @Test func subscriptKnownKindsCoverAllCases() {
        let reaction = OctopusTheme.Assets.Icons.Content.Reaction()
        for kind in ReactionKind.knownValues {
            let image = reaction[kind]
            #expect(image.size.width > 0)
        }
    }

    @Test func subscriptUnknownReturnsGeneratedImage() {
        let reaction = OctopusTheme.Assets.Icons.Content.Reaction()
        let image = reaction[.unknown("🦄")]
        #expect(image.size.width > 0)
        #expect(image.size.height > 0)
    }
}
