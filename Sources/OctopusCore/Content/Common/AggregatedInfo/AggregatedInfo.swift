//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusGrpcModels
import SwiftProtobuf

public struct PollResult: Equatable, Sendable {
    struct OptionVote: Equatable, Sendable {
        let optionId: String
        let voteCount: Int
    }
    let votes: [OptionVote]
    public let totalVoteCount: Int
    public let resultsByOption: [String: Int]

    public let percentageResultsByOption: [String: Int]

    init(totalVoteCount: Int, votes: [OptionVote]) {
        self.votes = votes
        self.totalVoteCount = totalVoteCount
        self.resultsByOption = Dictionary(votes.map { ($0.optionId, Int($0.voteCount)) },
                                          uniquingKeysWith: { first, _ in first })
        self.percentageResultsByOption = Self.calculateVotesPercentages(votes: votes)
    }

    private static func calculateVotesPercentages(votes: [OptionVote]) -> [String: Int] {
        let totalVotes = votes.reduce(0) { $0 + $1.voteCount }
        guard totalVotes > 0 else { return votes.reduce(into: [:]) { $0[$1.optionId] = 0 } }

        // Step 1: Calculate initial floating-point percentages
        let percentages = votes.map { ($0.optionId, (Double($0.voteCount) / Double(totalVotes)) * 100.0) }

        // Step 2: Convert to integers (truncation)
        var integerPercentages = Dictionary(uniqueKeysWithValues: percentages.map { ($0.0, Int($0.1)) })

        // Step 3: Compute the difference to track rounding errors
        var remainders = percentages.map { ($0.0, $0.1 - Double(integerPercentages[$0.0]!)) }

        // Step 4: Compute the sum of the integer percentages
        let sum = integerPercentages.values.reduce(0, +)

        // Step 5: Distribute the missing percentage points (due to truncation)
        let difference = 100 - sum
        if difference > 0 {
            // Sort remainders descending and give extra points to the biggest remainders
            remainders.sort { $0.1 > $1.1 }
            for i in 0..<difference {
                let key = remainders[i].0
                integerPercentages[key]! += 1
            }
        }

        return integerPercentages
    }
}

extension PollResult {
    init(from pollResult: Com_Octopuscommunity_PollResult) {
        self.init(
            totalVoteCount: Int(pollResult.totalVoteCount),
            votes: pollResult.answerResults.map { .init(optionId: $0.pollAnswerID, voteCount: Int($0.voteCount)) })
    }
}

extension PollResult.OptionVote {
    init(from entity: PollOptionResultEntity) {
        optionId = entity.optionId
        voteCount = entity.voteCount

    }
}

public struct AggregatedInfo: Equatable, Sendable {
    public let likeCount: Int
    public let childCount: Int
    public let viewCount: Int
    public let pollResult: PollResult?
}

extension AggregatedInfo {
    public static let empty: AggregatedInfo = .init(likeCount: 0, childCount: 0, viewCount: 0, pollResult: nil)

    init(from aggregate: Com_Octopuscommunity_Aggregate) {
        likeCount = Int(aggregate.likeCount)
        childCount = Int(aggregate.childrenCount)
        viewCount = Int(aggregate.viewCount)
        if aggregate.hasPollResult {
            pollResult = .init(from: aggregate.pollResult)
        } else {
            pollResult = nil
        }
    }

    init(from entity: OctoObjectEntity) {
        likeCount = entity.likeCount
        childCount = entity.childCount
        viewCount = entity.viewCount
        if let pollResults = entity.pollResults {
            pollResult = .init(totalVoteCount: entity.pollTotalVoteCount, votes: pollResults.map { .init(from: $0) })
        } else {
            pollResult = nil
        }
    }
}
