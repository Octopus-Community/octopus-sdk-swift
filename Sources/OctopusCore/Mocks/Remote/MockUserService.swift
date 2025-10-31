//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusRemoteClient
import OctopusGrpcModels

class MockUserService: UserService {
    /// Fifo of the responses to `getPublicProfile`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var getPublicProfileResponses = [Com_Octopuscommunity_GetPublicProfileResponse]()
    /// Fifo of the responses to `getProfile`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var getPrivateProfileResponses = [Com_Octopuscommunity_GetPrivateProfileResponse]()
    /// Fifo of the responses to `updateProfile`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var updateProfileResponses = [Com_Octopuscommunity_UpdateProfileResponse]()
    /// Fifo of the responses to `deleteAccount`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var deleteAccountResponses = [Com_Octopuscommunity_DeleteMyProfileResponse]()
    /// Fifo of the responses to `reportUser`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var reportUserResponses = [Com_Octopuscommunity_ReportUserResponse]()
    /// Fifo of the responses to `blockUser`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var blockUserResponses = [Com_Octopuscommunity_BlockUserResponse]()
    /// Fifo of the responses to `getJwtFromClientToken`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var getJwtFromClientTokenResponses = [Com_Octopuscommunity_GetJwtFromClientSignedTokenResponse]()
    /// Fifo of the responses to `getGuestJwt`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var getGuestJwtResponses = [Com_Octopuscommunity_GetGuestJwtResponse]()
    /// Fifo of the responses to `canAccessCommunity`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var canAccessCommunityResponses = [Com_Octopuscommunity_CanAccessCommunityResponse]()
    /// Fifo of the responses to `bypassABTesting`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var bypassABTestingResponses = [Com_Octopuscommunity_ByPassAbTestingResponse]()

    private(set) var errorMessage: String?


    func getPublicProfile(profileId: String, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetPublicProfileResponse {
        guard let response = getPublicProfileResponses.popLast() else {
            let message = "Dev error, injectNextGetPublicProfileResponse must be called before"
            errorMessage = message
            throw .unknown(MockError(message))
        }
        return response
    }

    func getPrivateProfile(userId: String, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetPrivateProfileResponse {
        guard let response = getPrivateProfileResponses.popLast() else {
            let message = "Dev error, injectNextGetPrivateProfileResponse must be called before"
            errorMessage = message
            throw .unknown(MockError(message))
        }
        return response
    }

    func updateProfile(userId: String,
                       profile: UpdateProfileData,
                       authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_UpdateProfileResponse {
        guard let response = updateProfileResponses.popLast() else {
            let message = "Dev error, injectNextUpdateProfileResponse must be called before"
            errorMessage = message
            throw .unknown(MockError(message))
        }
        return response
    }

    func deleteUser(userId: String, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_DeleteUserResponse {
        fatalError("Not implemented")
    }

    func deleteAccount(userId: String, reason: Com_Octopuscommunity_DeleteMyProfileRequest.DeleteMyProfileReason,
                       authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_DeleteMyProfileResponse {
        guard let response = deleteAccountResponses.popLast() else {
            let message = "Dev error, injectNextDeleteProfileResponse must be called before"
            errorMessage = message
            throw .unknown(MockError(message))
        }
        return response
    }

    func reportUser(profileId: String, reasons: [Com_Octopuscommunity_ReportReasonCode],
                    authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_ReportUserResponse {
        guard let response = reportUserResponses.popLast() else {
            let message = "Dev error, injectNextDeleteProfileResponse must be called before"
            errorMessage = message
            throw .unknown(MockError(message))
        }
        return response
    }

    func blockUser(profileId: String, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_BlockUserResponse {
        guard let response = blockUserResponses.popLast() else {
            let message = "Dev error, injectNextBlockUserResponse must be called before"
            errorMessage = message
            throw .unknown(MockError(message))
        }
        return response
    }

    func getJwt(clientToken: String, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetJwtFromClientSignedTokenResponse {
        try? await Task.sleep(nanoseconds: UInt64.random(in: 0..<10) * 1_000_000)
        guard let response = getJwtFromClientTokenResponses.popLast() else {
            let message = "Dev error, injectNextGetJwtFromClientResponse must be called before"
            errorMessage = message
            throw .unknown(MockError(message))
        }
        return response
    }

    func getGuestJwt() async throws(RemoteClientError) -> Com_Octopuscommunity_GetGuestJwtResponse {
        do {
            try await Task.sleep(nanoseconds: UInt64.random(in: 0..<10) * 1_000_000)
        } catch { throw .unknown(MockError("Unknown error")) }
        guard let response = getGuestJwtResponses.popLast() else {
            let message = "Dev error, injectNextGetGuestJwt must be called before"
            errorMessage = message
            throw .unknown(MockError(message))
        }
        return response
    }

    func canAccessCommunity(authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError) -> Com_Octopuscommunity_CanAccessCommunityResponse {
        guard let response = canAccessCommunityResponses.popLast() else {
            let message = "Dev error, injectNextBlockUserResponse must be called before"
            errorMessage = message
            throw .unknown(MockError(message))
        }
        return response
    }

    func bypassABTestingAccess(userId: String, canAccessCommunity: Bool, authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError) -> Com_Octopuscommunity_ByPassAbTestingResponse {
        guard let response = bypassABTestingResponses.popLast() else {
            let message = "Dev error, injectNextBlockUserResponse must be called before"
            errorMessage = message
            throw .unknown(MockError(message))
        }
        return response
    }
}

extension MockUserService {
    func injectNextGetPublicProfileResponse(_ response: Com_Octopuscommunity_GetPublicProfileResponse) {
        getPublicProfileResponses.insert(response, at: 0)
    }

    func injectNextGetPrivateProfileResponse(_ response: Com_Octopuscommunity_GetPrivateProfileResponse) {
        getPrivateProfileResponses.insert(response, at: 0)
    }

    func injectNextUpdateProfileResponse(_ response: Com_Octopuscommunity_UpdateProfileResponse) {
        updateProfileResponses.insert(response, at: 0)
    }

    func injectNextDeleteAccountResponse(_ response: Com_Octopuscommunity_DeleteMyProfileResponse) {
        deleteAccountResponses.insert(response, at: 0)
    }

    func injectNextReportUserResponse(_ response: Com_Octopuscommunity_ReportUserResponse) {
        reportUserResponses.insert(response, at: 0)
    }

    func injectNextBlockUserResponse(_ response: Com_Octopuscommunity_BlockUserResponse) {
        blockUserResponses.insert(response, at: 0)
    }

    func injectNextGetJwtFromClientResponse(_ response: Com_Octopuscommunity_GetJwtFromClientSignedTokenResponse) {
        getJwtFromClientTokenResponses.insert(response, at: 0)
    }

    func injectNextGetGuestJwtResponse(_ response: Com_Octopuscommunity_GetGuestJwtResponse) {
        getGuestJwtResponses.insert(response, at: 0)
    }
}
