//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusGrpcModels
@testable import OctopusCore

/// `ValidationErrors(from:)` for a refused reaction or poll vote: neither form has a field, so every error is shown
/// as an alert, in the order the server sent them.
struct InteractionErrorsMappingTests {

    @Test func reactionErrorsAreAlerts() {
        let errors = ValidationErrors<Reaction.Field, Reaction.ErrorDetail>(
            from: Com_Octopuscommunity_PutReactionResponse.Fail.with {
                $0.errors = [
                    .with { $0.message = "Content deleted"; $0.field = .contentParent; $0.missingParent = .init() },
                    .with { $0.message = "Something went wrong" }
                ]
            })

        #expect(Array(errors.errors.keys) == [.alert])
        let alerts = errors.errors[.alert] ?? []
        #expect(alerts.map(\.localizedMessage) == ["Content deleted", "Something went wrong"])
        #expect(alerts.map(\.detail) == [.missingParent, .unknown])
    }

    @Test func pollVoteErrorsAreAlerts() {
        let errors = ValidationErrors<PollVote.Field, PollVote.ErrorDetail>(
            from: Com_Octopuscommunity_PutPollVoteResponse.Fail.with {
                $0.errors = [
                    .with { $0.message = "Post deleted"; $0.field = .contentParent; $0.missingParent = .init() },
                    .with { $0.message = "Option removed"; $0.field = .contentTarget; $0.missingPollAnswer = .init() },
                    .with { $0.message = "Something went wrong"; $0.field = .UNRECOGNIZED(42) }
                ]
            })

        #expect(Array(errors.errors.keys) == [.alert])
        let alerts = errors.errors[.alert] ?? []
        #expect(alerts.map(\.localizedMessage) == ["Post deleted", "Option removed", "Something went wrong"])
        #expect(alerts.map(\.detail) == [.missingParent, .missingPollAnswer, .unknown])
    }

    @Test func noErrorMeansAnEmptyDictionary() {
        let reaction = ValidationErrors<Reaction.Field, Reaction.ErrorDetail>(
            from: Com_Octopuscommunity_PutReactionResponse.Fail())
        let pollVote = ValidationErrors<PollVote.Field, PollVote.ErrorDetail>(
            from: Com_Octopuscommunity_PutPollVoteResponse.Fail())

        #expect(reaction.errors.isEmpty)
        #expect(pollVote.errors.isEmpty)
    }
}
