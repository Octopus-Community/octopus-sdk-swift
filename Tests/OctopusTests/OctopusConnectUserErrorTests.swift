//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusGrpcModels
@testable import Octopus
@testable import OctopusCore

@Suite
struct OctopusConnectUserErrorTests {

    // MARK: - From ConnectionError

    @Test func connectionErrorNoNetwork() {
        let error = OctopusConnectUserError(from: ConnectionError.noNetwork)
        guard case .noNetwork = error else {
            Issue.record("Expected .noNetwork, got \(error)")
            return
        }
    }

    @Test func connectionErrorDetailedErrorsWithUserBanned() {
        let detailed = makeConnectionDetailedError(reason: .userBanned, message: "Banned")
        let error = OctopusConnectUserError(from: ConnectionError.detailedErrors([detailed]) as Error)
        guard case let .userBanned(message) = error else {
            Issue.record("Expected .userBanned, got \(error)")
            return
        }
        #expect(message == "Banned")
    }

    @Test func connectionErrorDetailedErrorsWithUnknownReason() {
        let detailed = makeConnectionDetailedError(reason: .unknown, message: "Something")
        let error = OctopusConnectUserError(from: ConnectionError.detailedErrors([detailed]) as Error)
        guard case .other = error else {
            Issue.record("Expected .other, got \(error)")
            return
        }
    }

    @Test func connectionErrorServer() {
        let serverError = ServerError.timeout
        let error = OctopusConnectUserError(from: ConnectionError.server(serverError) as Error)
        guard case let .server(inner) = error else {
            Issue.record("Expected .server, got \(error)")
            return
        }
        #expect(inner is ServerError)
    }

    @Test func connectionErrorProfileUpdateValidation() {
        let validationErrors = makeValidationErrors(
            [.linkedToField(.nickname): [.init(localizedMessage: "Already taken", detail: .alreadyTaken)]])
        let updateError: UpdateProfile.Error = .validation(validationErrors)
        let error = OctopusConnectUserError(from: ConnectionError.profileUpdateError(updateError) as Error)
        guard case let .profileError(profileErrors) = error else {
            Issue.record("Expected .profileError, got \(error)")
            return
        }
        #expect(profileErrors.count == 1)
        #expect(profileErrors.first?.field == .nickname)
        guard case .alreadyTaken = profileErrors.first?.errorKind else {
            Issue.record("Expected .alreadyTaken, got \(String(describing: profileErrors.first?.errorKind))")
            return
        }
        #expect(profileErrors.first?.message == "Already taken")
    }

    @Test func connectionErrorProfileUpdateServerCall() {
        let updateError: UpdateProfile.Error = .serverCall(.noNetwork)
        let error = OctopusConnectUserError(from: ConnectionError.profileUpdateError(updateError) as Error)
        guard case .noNetwork = error else {
            Issue.record("Expected .noNetwork, got \(error)")
            return
        }
    }

    @Test func connectionErrorProfileUpdateServerError() {
        let updateError: UpdateProfile.Error = .serverCall(.serverError(.timeout))
        let error = OctopusConnectUserError(from: ConnectionError.profileUpdateError(updateError) as Error)
        guard case .server = error else {
            Issue.record("Expected .server, got \(error)")
            return
        }
    }

    @Test func connectionErrorProfileUpdateOther() {
        let updateError: UpdateProfile.Error = .other(NSError(domain: "test", code: 1))
        let error = OctopusConnectUserError(from: ConnectionError.profileUpdateError(updateError) as Error)
        guard case .other = error else {
            Issue.record("Expected .other, got \(error)")
            return
        }
    }

    @Test func connectionErrorUnknown() {
        let error = OctopusConnectUserError(from: ConnectionError.unknown(NSError(domain: "test", code: 1)) as Error)
        guard case .other = error else {
            Issue.record("Expected .other, got \(error)")
            return
        }
    }

    @Test func connectionErrorUnknownNil() {
        let error = OctopusConnectUserError(from: ConnectionError.unknown(nil) as Error)
        guard case .other = error else {
            Issue.record("Expected .other, got \(error)")
            return
        }
    }

    @Test func connectionErrorJwtError() {
        let error = OctopusConnectUserError(from: ConnectionError.jwtError as Error)
        guard case .jwtError = error else {
            Issue.record("Expected .jwtError, got \(error)")
            return
        }
    }

    @Test func connectionErrorCommunityAccessDenied() {
        let error = OctopusConnectUserError(from: ConnectionError.communityAccessDenied as Error)
        guard case .communityAccessDenied = error else {
            Issue.record("Expected .communityAccessDenied, got \(error)")
            return
        }
    }

    // MARK: - From ExchangeTokenError

    @Test func exchangeTokenErrorNoNetwork() {
        let error = OctopusConnectUserError(from: ExchangeTokenError.noNetwork as Error)
        guard case .noNetwork = error else {
            Issue.record("Expected .noNetwork, got \(error)")
            return
        }
    }

    @Test func exchangeTokenErrorDetailedErrorsWithUserBanned() {
        let detailed = makeExchangeTokenDetailedError(reason: .userBanned, message: "Banned")
        let error = OctopusConnectUserError(from: ExchangeTokenError.detailedErrors([detailed]) as Error)
        guard case let .userBanned(message) = error else {
            Issue.record("Expected .userBanned, got \(error)")
            return
        }
        #expect(message == "Banned")
    }

    @Test func exchangeTokenErrorDetailedErrorsWithUnknownReason() {
        let detailed = makeExchangeTokenDetailedError(reason: .unknown, message: "Something")
        let error = OctopusConnectUserError(from: ExchangeTokenError.detailedErrors([detailed]) as Error)
        guard case .other = error else {
            Issue.record("Expected .other, got \(error)")
            return
        }
    }

    @Test func exchangeTokenErrorServer() {
        let serverError = ServerError.timeout
        let error = OctopusConnectUserError(from: ExchangeTokenError.server(serverError) as Error)
        guard case let .server(inner) = error else {
            Issue.record("Expected .server, got \(error)")
            return
        }
        #expect(inner is ServerError)
    }

    @Test func exchangeTokenErrorJwtError() {
        let error = OctopusConnectUserError(from: ExchangeTokenError.jwtError as Error)
        guard case .jwtError = error else {
            Issue.record("Expected .jwtError, got \(error)")
            return
        }
    }

    @Test func exchangeTokenErrorCommunityAccessDenied() {
        let error = OctopusConnectUserError(from: ExchangeTokenError.communityAccessDenied as Error)
        guard case .communityAccessDenied = error else {
            Issue.record("Expected .communityAccessDenied, got \(error)")
            return
        }
    }

    @Test func exchangeTokenErrorProfileUpdateValidation() {
        let validationErrors = makeValidationErrors([
            .linkedToField(.bio): [.init(localizedMessage: "Bad words", detail: .bannedWordUsed(["word1"]))],
            .linkedToField(.nickname): [.init(localizedMessage: "Too long", detail: .maxCharLimitReached)]
        ])
        let updateError: UpdateProfile.Error = .validation(validationErrors)
        let error = OctopusConnectUserError(from: ExchangeTokenError.profileUpdateError(updateError) as Error)
        guard case let .profileError(profileErrors) = error else {
            Issue.record("Expected .profileError, got \(error)")
            return
        }
        #expect(profileErrors.count == 2)

        let bioError = profileErrors.first { $0.field == .bio }
        #expect(bioError != nil)
        guard case let .bannedWordUsed(words) = bioError?.errorKind else {
            Issue.record("Expected .bannedWordUsed, got \(String(describing: bioError?.errorKind))")
            return
        }
        #expect(words == ["word1"])

        let nicknameError = profileErrors.first { $0.field == .nickname }
        #expect(nicknameError != nil)
        guard case .maxCharLimitReached = nicknameError?.errorKind else {
            Issue.record("Expected .maxCharLimitReached, got \(String(describing: nicknameError?.errorKind))")
            return
        }
    }

    @Test func exchangeTokenErrorProfileUpdateServerCall() {
        let updateError: UpdateProfile.Error = .serverCall(.noNetwork)
        let error = OctopusConnectUserError(from: ExchangeTokenError.profileUpdateError(updateError) as Error)
        guard case .noNetwork = error else {
            Issue.record("Expected .noNetwork, got \(error)")
            return
        }
    }

    @Test func exchangeTokenErrorProfileUpdateUserNotAuthenticated() {
        let updateError: UpdateProfile.Error = .serverCall(.userNotAuthenticated)
        let error = OctopusConnectUserError(from: ExchangeTokenError.profileUpdateError(updateError) as Error)
        guard case .other = error else {
            Issue.record("Expected .other, got \(error)")
            return
        }
    }

    @Test func exchangeTokenErrorUnknown() {
        let error = OctopusConnectUserError(from: ExchangeTokenError.unknown(NSError(domain: "test", code: 1)) as Error)
        guard case .other = error else {
            Issue.record("Expected .other, got \(error)")
            return
        }
    }

    // MARK: - From unknown Error

    @Test func unknownErrorType() {
        let error = OctopusConnectUserError(from: NSError(domain: "test", code: 42) as Error)
        guard case .other = error else {
            Issue.record("Expected .other, got \(error)")
            return
        }
    }

    // MARK: - Profile validation error field mapping

    @Test func profileValidationAlertFieldMapsToNil() {
        let validationErrors = makeValidationErrors(
            [.alert: [.init(localizedMessage: "Alert error", detail: .unknown)]])
        let updateError: UpdateProfile.Error = .validation(validationErrors)
        let error = OctopusConnectUserError(from: ConnectionError.profileUpdateError(updateError) as Error)
        guard case let .profileError(profileErrors) = error else {
            Issue.record("Expected .profileError, got \(error)")
            return
        }
        #expect(profileErrors.count == 1)
        #expect(profileErrors.first?.field == nil)
    }

    @Test func profileValidationPictureField() {
        let validationErrors = makeValidationErrors(
            [.linkedToField(.picture): [.init(localizedMessage: "Too big", detail: .fileSizeTooBig)]])
        let updateError: UpdateProfile.Error = .validation(validationErrors)
        let error = OctopusConnectUserError(from: ConnectionError.profileUpdateError(updateError) as Error)
        guard case let .profileError(profileErrors) = error else {
            Issue.record("Expected .profileError, got \(error)")
            return
        }
        #expect(profileErrors.first?.field == .picture)
        guard case .fileSizeTooBig = profileErrors.first?.errorKind else {
            Issue.record("Expected .fileSizeTooBig, got \(String(describing: profileErrors.first?.errorKind))")
            return
        }
    }
}

// MARK: - Helpers

private func makeConnectionDetailedError(
    reason: ConnectionError.DetailedError.Reason,
    message: String
) -> ConnectionError.DetailedError {
    let protoError = Com_Octopuscommunity_GetGuestJwtResponse.Error.with {
        $0.message = message
        $0.errorCode = .unknownError
    }
    let error = ConnectionError.DetailedError(from: protoError)
    if reason == .userBanned {
        let protoJwtError = Com_Octopuscommunity_GetJwtFromClientSignedTokenResponse.Error.with {
            $0.message = message
            $0.errorCode = .userBanned
        }
        let bannedExchange = ExchangeTokenError.DetailedError(from: protoJwtError)
        return ConnectionError.DetailedError(from: bannedExchange)
    }
    return error
}

private func makeExchangeTokenDetailedError(
    reason: ExchangeTokenError.DetailedError.Reason,
    message: String
) -> ExchangeTokenError.DetailedError {
    if reason == .userBanned {
        return ExchangeTokenError.DetailedError(
            from: Com_Octopuscommunity_GetJwtFromClientSignedTokenResponse.Error.with {
                $0.message = message
                $0.errorCode = .userBanned
            })
    }
    return ExchangeTokenError.DetailedError(
        from: Com_Octopuscommunity_GetJwtFromClientSignedTokenResponse.Error.with {
            $0.message = message
            $0.errorCode = .unknownError
        })
}

private func makeValidationErrors(
    _ dict: [ValidationErrors<UpdateProfile.Field, UpdateProfile.ErrorDetail>.DisplayKind:
        [ValidationErrors<UpdateProfile.Field, UpdateProfile.ErrorDetail>.Error]]
) -> ValidationErrors<UpdateProfile.Field, UpdateProfile.ErrorDetail> {
    ValidationErrors<UpdateProfile.Field, UpdateProfile.ErrorDetail>(errors: dict)
}
