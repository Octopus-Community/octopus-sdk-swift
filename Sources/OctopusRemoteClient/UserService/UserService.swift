//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
#if canImport(GRPC)
import GRPC
#else
import GRPCSwift
#endif
import OctopusGrpcModels
import Logging

public struct UpdateProfileData: Sendable {
    public enum FieldUpdate<T: Sendable>: Sendable {
        case notUpdated
        case updated(T)
    }

    public let nickname: FieldUpdate<String>
    public let bio: FieldUpdate<String?>
    public let picture: FieldUpdate<(imgData: Data, isCompressed: Bool)?>
    public let hasSeenOnboarding: FieldUpdate<Bool>
    public let hasAcceptedCgu: FieldUpdate<Bool>
    public let hasConfirmedNickname: FieldUpdate<Bool>
    public let hasConfirmedBio: FieldUpdate<Bool>
    public let hasConfirmedPicture: FieldUpdate<Bool>
    public let optFindAvailableNickname: Bool

    public init(nickname: FieldUpdate<String> = .notUpdated,
                bio: FieldUpdate<String?> = .notUpdated,
                picture: FieldUpdate<(imgData: Data, isCompressed: Bool)?> = .notUpdated,
                hasSeenOnboarding: FieldUpdate<Bool> = .notUpdated,
                hasAcceptedCgu: FieldUpdate<Bool> = .notUpdated,
                hasConfirmedNickname: FieldUpdate<Bool> = .notUpdated,
                hasConfirmedBio: FieldUpdate<Bool> = .notUpdated,
                hasConfirmedPicture: FieldUpdate<Bool> = .notUpdated,
                optFindAvailableNickname: Bool = false
    ) {
        self.nickname = nickname
        self.bio = bio
        self.picture = picture
        self.hasSeenOnboarding = hasSeenOnboarding
        self.hasAcceptedCgu = hasAcceptedCgu
        self.hasConfirmedNickname = hasConfirmedNickname
        self.hasConfirmedBio = hasConfirmedBio
        self.hasConfirmedPicture = hasConfirmedPicture
        self.optFindAvailableNickname = optFindAvailableNickname
    }
}


public protocol UserService {
    func getPrivateProfile(
        userId: String,
        authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetPrivateProfileResponse

    func updateProfile(userId: String,
                       profile: UpdateProfileData,
                       authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_UpdateProfileResponse

    func getPublicProfile(
        profileId: String,
        authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetPublicProfileResponse

    func deleteUser(userId: String, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_DeleteUserResponse

    func deleteAccount(userId: String, reason: Com_Octopuscommunity_DeleteMyProfileRequest.DeleteMyProfileReason,
                       authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_DeleteMyProfileResponse

    func reportUser(profileId: String, reasons: [Com_Octopuscommunity_ReportReasonCode],
                    authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_ReportUserResponse

    func blockUser(profileId: String, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_BlockUserResponse

    func getJwt(clientToken: String, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetJwtFromClientSignedTokenResponse

    func getGuestJwt() async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetGuestJwtResponse

    func canAccessCommunity(authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_CanAccessCommunityResponse

    func bypassABTestingAccess(userId: String, canAccessCommunity: Bool, authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError) -> Com_Octopuscommunity_ByPassAbTestingResponse

    func enteringOctopus(authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError) -> Com_Octopuscommunity_EnteringOctopusResponse
}

class UserServiceClient: ServiceClient, UserService {
    private let client: Com_Octopuscommunity_UserServiceAsyncClient

    init(unaryChannel: GRPCChannel, apiKey: String, sdkVersion: String, installId: String, localeIdentifier: String,
         getUserIdBlock:  @escaping () -> String?,
         updateTokenBlock: @escaping (String) -> Void) {
        client = Com_Octopuscommunity_UserServiceAsyncClient(
            channel: unaryChannel, interceptors: UserServiceInterceptor(
                getUserIdBlock: getUserIdBlock, updateTokenBlock: updateTokenBlock))
        super.init(apiKey: apiKey, sdkVersion: sdkVersion, installId: installId, localeIdentifier: localeIdentifier)
    }

    func getPublicProfile(
        profileId: String,
        authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetPublicProfileResponse {
        let request = Com_Octopuscommunity_GetPublicProfileRequest.with {
            $0.userID = profileId
            $0.fetchTotalMessages = true
            $0.fetchGamification = true
        }
        return try await callRemote(authenticationMethod) {
            try await client.getPublicProfile(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }

    public func getPrivateProfile(
        userId: String,
        authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetPrivateProfileResponse {
        let request = Com_Octopuscommunity_GetPrivateProfileRequest.with {
            $0.userID = userId
            $0.fetchUserBlockList = true
            $0.fetchNotificationsBadge = true
            $0.fetchTotalMessages = true
            $0.fetchGamification = true
        }
        return try await callRemote(authenticationMethod) {
            try await client.getPrivateProfile(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }

    public func updateProfile(userId: String,
                              profile: UpdateProfileData,
                              authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_UpdateProfileResponse {
        let request = Com_Octopuscommunity_UpdateProfileRequest.with {
            $0.userID = userId
            $0.update = .with {
                if case let .updated(nickname) = profile.nickname {
                    $0.nickname = nickname
                }
                if case let .updated(bio) = profile.bio {
                    $0.bio = bio ?? ""
                }
                if case let .updated(pictureInfo) = profile.picture {
                    $0.picture = .with {
                        $0.request = if let pictureInfo {
                            .new(.with {
                                $0.file = pictureInfo.imgData
                                $0.isOptimized = pictureInfo.isCompressed
                            })
                        } else {
                            .delete(Com_Octopuscommunity_PictureDeleteRequest())
                        }
                    }
                }
                if case let .updated(hasSeenOnboarding) = profile.hasSeenOnboarding {
                    $0.hasSeenOnboarding_p = hasSeenOnboarding
                }
                if case let .updated(hasAcceptedCgu) = profile.hasAcceptedCgu {
                    $0.hasAcceptedCgu_p = hasAcceptedCgu
                }
                if case let .updated(hasConfirmedNickname) = profile.hasConfirmedNickname {
                    $0.hasConfirmedNickname_p = hasConfirmedNickname
                }
                if case let .updated(hasConfirmedBio) = profile.hasConfirmedBio {
                    $0.hasConfirmedBio_p = hasConfirmedBio
                }
                if case let .updated(hasConfirmedPicture) = profile.hasConfirmedPicture {
                    $0.hasConfirmedPicture_p = hasConfirmedPicture
                }
                $0.optFindAvailableNickname = profile.optFindAvailableNickname
            }

            // TODO: Djavan only set to true when it is a profile update, not only hasSeenOnboarding or hasAcceptedCgu
            $0.fetchUserBlockList = true
            $0.fetchNotificationsBadge = true
            $0.fetchTotalMessages = true
            $0.fetchGamification = true
        }
        return try await callRemote(authenticationMethod) {
            return try await client.updateProfile(
                request,
                callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }

    public func deleteUser(userId: String, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_DeleteUserResponse {
        let request = Com_Octopuscommunity_DeleteUserRequest.with {
            $0.userID = userId
        }
        return try await callRemote(authenticationMethod) {
            try await client.deleteUser(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }

    func deleteAccount(userId: String, reason: Com_Octopuscommunity_DeleteMyProfileRequest.DeleteMyProfileReason,
                       authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_DeleteMyProfileResponse {
        let request = Com_Octopuscommunity_DeleteMyProfileRequest.with {
            $0.userID = userId
            $0.reason = reason
        }
        return try await callRemote(authenticationMethod) {
            try await client.deleteMyProfile(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }

    func reportUser(profileId: String, reasons: [Com_Octopuscommunity_ReportReasonCode],
                    authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_ReportUserResponse {
        let request = Com_Octopuscommunity_ReportUserRequest.with {
            $0.userID = profileId
            $0.reasonCodes = reasons
        }
        return try await callRemote(authenticationMethod) {
            try await client.reportUser(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }

    func blockUser(profileId: String, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_BlockUserResponse {
        let request = Com_Octopuscommunity_BlockUserRequest.with {
            $0.userID = profileId
        }
        return try await callRemote(authenticationMethod) {
            try await client.blockUser(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }

    func getJwt(clientToken: String, authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetJwtFromClientSignedTokenResponse {
        let request = Com_Octopuscommunity_GetJwtFromClientSignedTokenRequest.with {
            $0.clientToken = clientToken
        }
        return try await callRemote(authenticationMethod) {
            try await client.getJwtFromClientSignedToken(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }

    func getGuestJwt() async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetGuestJwtResponse {
        let request = Com_Octopuscommunity_GetGuestJwtRequest()

        return try await callRemote(.notAuthenticated) {
            try await client.getGuestJwt(
                request, callOptions: getCallOptions(authenticationMethod: .notAuthenticated))
        }
    }

    func canAccessCommunity(authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_CanAccessCommunityResponse {
        let request = Com_Octopuscommunity_CanAccessCommunityRequest()

        return try await callRemote(authenticationMethod) {
            try await client.canAccessCommunity(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }

    func bypassABTestingAccess(userId: String, canAccessCommunity: Bool, authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError) -> Com_Octopuscommunity_ByPassAbTestingResponse {
        let request = Com_Octopuscommunity_ByPassAbTestingRequest.with {
            $0.userID = userId
            $0.giveCommunityAccess = canAccessCommunity
        }

        return try await callRemote(authenticationMethod) {
            try await client.byPassAbTesting(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }

    func enteringOctopus(authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError) -> Com_Octopuscommunity_EnteringOctopusResponse {
        let request = Com_Octopuscommunity_EnteringOctopusRequest.with {
            $0.fetchGamificationToasts = true
        }

        return try await callRemote(authenticationMethod) {
            try await client.enteringOctopus(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }
}
