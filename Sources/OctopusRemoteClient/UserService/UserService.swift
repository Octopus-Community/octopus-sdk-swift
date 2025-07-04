//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import GRPC
import OctopusGrpcModels
import Logging

public enum FieldUpdate<T> {
    case notUpdated
    case updated(T)
}

public protocol UserService {
    func getPrivateProfile(
        userId: String,
        authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetPrivateProfileResponse

    func updateProfile(userId: String,
                       nickname: FieldUpdate<String>,
                       bio: FieldUpdate<String?>,
                       picture: FieldUpdate<(imgData: Data, isCompressed: Bool)?>,
                       isProfileCreation: Bool,
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

    func getJwt(clientToken: String) async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetJwtFromClientSignedTokenResponse
}

class UserServiceClient: ServiceClient, UserService {
    private let client: Com_Octopuscommunity_UserServiceAsyncClient


    init(unaryChannel: GRPCChannel, apiKey: String, sdkVersion: String, installId: String,
         updateTokenBlock: @escaping (String) -> Void) {
        client = Com_Octopuscommunity_UserServiceAsyncClient(
            channel: unaryChannel, interceptors: UserServiceInterceptor(updateTokenBlock: updateTokenBlock))
        super.init(apiKey: apiKey, sdkVersion: sdkVersion, installId: installId)
    }

    func getPublicProfile(
        profileId: String,
        authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetPublicProfileResponse {
        let request = Com_Octopuscommunity_GetPublicProfileRequest.with {
            $0.userID = profileId
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
        }
        return try await callRemote(authenticationMethod) {
            try await client.getPrivateProfile(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }

    public func updateProfile(userId: String,
                              nickname: FieldUpdate<String>,
                              bio: FieldUpdate<String?>,
                              picture: FieldUpdate<(imgData: Data, isCompressed: Bool)?>,
                              isProfileCreation: Bool,
                              authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_UpdateProfileResponse {
        let request = Com_Octopuscommunity_UpdateProfileRequest.with {
            $0.userID = userId
            $0.update = .with {
                if case let .updated(nickname) = nickname {
                    $0.nickname = nickname
                }
                if case let .updated(bio) = bio {
                    $0.bio = bio ?? ""
                }
                if case let .updated(pictureInfo) = picture {
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
            }
        }
        return try await callRemote(authenticationMethod) {
            if isProfileCreation {
                return try await client.createProfile(
                    request,
                    callOptions: getCallOptions(authenticationMethod: authenticationMethod))
            } else {
                return try await client.updateProfile(
                    request,
                    callOptions: getCallOptions(authenticationMethod: authenticationMethod))
            }
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

    func getJwt(clientToken: String) async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetJwtFromClientSignedTokenResponse {
        let request = Com_Octopuscommunity_GetJwtFromClientSignedTokenRequest.with {
            $0.clientToken = clientToken
        }
        return try await callRemote(.notAuthenticated) {
            try await client.getJwtFromClientSignedToken(
                request, callOptions: getCallOptions(authenticationMethod: .notAuthenticated))
        }
    }
}
