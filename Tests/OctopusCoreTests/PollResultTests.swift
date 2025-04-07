//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusCore

struct PollResultTests {
    struct VoteResults {
        let count: [Int]
        let expectedPercentage: [Int]
    }

    @Test(arguments: [
        // If only one option has votes, expect 100% on this option
        VoteResults(count: [5], expectedPercentage: [100]),
        // Ensure equality in % is distributed with priority on the first option with equality
        VoteResults(count: [6, 1, 1], expectedPercentage: [75, 13, 12]),
        // Ensure equality in % is distributed with priority on the first option with equality
        VoteResults(count: [1, 1, 1, 0], expectedPercentage: [34, 33, 33, 0]),
        // Ensure equality in % is distributed with priority on the first option with equality
        VoteResults(count: [1, 1, 1, 1, 1, 1], expectedPercentage: [17, 17, 17, 17, 16, 16]),
        // When no vote, all % should be 0
        VoteResults(count: [0, 0], expectedPercentage: [0, 0]),
    ])
    private func ensurePercentagesAreCorrect(results: VoteResults) throws {
        let totalVotes = results.count.reduce(0, +)
        // put VoteResults.count in a dictionary, indexed by the index in the array
        let votes = results.count.enumerated().map { PollResult.OptionVote(optionId: "\($0)", voteCount: $1) }
        // put VoteResults.expectedPercentage in a dictionary, indexed by the index in the array
        let expectedPercentages = Dictionary(uniqueKeysWithValues: results.expectedPercentage.enumerated().map { ("\($0)", $1) })

        // Create the struct to test
        let pollResults = PollResult(totalVoteCount: totalVotes, votes: votes)
        #expect(pollResults.percentageResultsByOption == expectedPercentages)
    }
}
