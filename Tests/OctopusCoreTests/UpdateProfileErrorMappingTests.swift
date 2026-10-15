//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
import OctopusGrpcModels
@testable import OctopusCore

/// Mapping of the server's profile update refusal onto `UpdateProfile.ErrorDetail`, for the taken nickname.
struct UpdateProfileErrorMappingTests {

    private func nicknameDetails(_ alreadyTaken: Com_Octopuscommunity_UpdateProfileResponse.Error.AlreadyTaken)
    -> [UpdateProfile.ErrorDetail] {
        let fail = Com_Octopuscommunity_UpdateProfileResponse.Fail.with {
            $0.errors = [.with {
                $0.field = .nickname
                $0.details = .alreadyTaken(alreadyTaken)
                $0.message = "Already taken"
            }]
        }
        let errors = ValidationErrors<UpdateProfile.Field, UpdateProfile.ErrorDetail>(from: fail)
        return errors.errors[.linkedToField(.nickname)]?.map(\.detail) ?? []
    }

    @Test func alreadyTakenCarriesTheSuggestions() {
        let details = nicknameDetails(.with { $0.suggestions = ["Marine_7", "Marine.b"] })

        guard case let .alreadyTaken(suggestions) = details.first else {
            Issue.record("Expected .alreadyTaken, got \(details)")
            return
        }
        #expect(suggestions == ["Marine_7", "Marine.b"])
    }

    @Test func alreadyTakenWithoutSuggestionsMapsToAnEmptyList() {
        let details = nicknameDetails(.init())

        guard case let .alreadyTaken(suggestions) = details.first else {
            Issue.record("Expected .alreadyTaken, got \(details)")
            return
        }
        #expect(suggestions.isEmpty)
    }
}
