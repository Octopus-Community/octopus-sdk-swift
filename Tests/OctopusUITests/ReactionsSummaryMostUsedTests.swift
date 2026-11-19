//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
import OctopusCore
@testable import OctopusUI

/// The reactions on the right of the post footer: the most used ones, whatever order they come in.
struct ReactionsSummaryMostUsedTests {
    @Test func keepsTheThreeMostUsedByCount() {
        let reactions: [ReactionCount] = [
            .init(reactionKind: .clap, count: 2),
            .init(reactionKind: .heart, count: 120),
            .init(reactionKind: .rage, count: 1),
            .init(reactionKind: .joy, count: 50),
            .init(reactionKind: .mouthOpen, count: 22)
        ]
        #expect(ReactionsSummary.mostUsed(reactions, max: 3) == [.heart, .joy, .mouthOpen])
    }

    @Test func aTieKeepsTheGivenOrder() {
        let reactions: [ReactionCount] = [
            .init(reactionKind: .joy, count: 3),
            .init(reactionKind: .heart, count: 3),
            .init(reactionKind: .clap, count: 5)
        ]
        #expect(ReactionsSummary.mostUsed(reactions, max: 3) == [.clap, .joy, .heart])
    }

    @Test func skipsReactionsNobodyUses() {
        let reactions: [ReactionCount] = [
            .init(reactionKind: .joy, count: 0),
            .init(reactionKind: .heart, count: 1)
        ]
        #expect(ReactionsSummary.mostUsed(reactions, max: 3) == [.heart])
        #expect(ReactionsSummary.mostUsed([], max: 3).isEmpty)
    }
}
