//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import GRPC
import OctopusGrpcModels

final class UserServiceInterceptor: Com_Octopuscommunity_UserServiceClientInterceptorFactoryProtocol, @unchecked Sendable {
    private let updateTokenBlock: (String) -> Void

    init(updateTokenBlock: @escaping (String) -> Void) {
        self.updateTokenBlock = updateTokenBlock
    }

    func makeDeleteUserInterceptors() -> [ClientInterceptor<Com_Octopuscommunity_DeleteUserRequest, Com_Octopuscommunity_DeleteUserResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeUpdateProfileInterceptors() -> [ClientInterceptor<Com_Octopuscommunity_UpdateProfileRequest, Com_Octopuscommunity_UpdateProfileResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeGetPublicProfileInterceptors() -> [ClientInterceptor<Com_Octopuscommunity_GetPublicProfileRequest, Com_Octopuscommunity_GetPublicProfileResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeGetPrivateProfileInterceptors() -> [ClientInterceptor<Com_Octopuscommunity_GetPrivateProfileRequest, Com_Octopuscommunity_GetPrivateProfileResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeBanUserInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_BanUserRequest, OctopusGrpcModels.Com_Octopuscommunity_BanUserResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeDeleteMyProfileInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_DeleteMyProfileRequest, OctopusGrpcModels.Com_Octopuscommunity_DeleteMyProfileResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeUnbanUserInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_UnbanUserRequest, OctopusGrpcModels.Com_Octopuscommunity_UnbanUserResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeReportUserInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_ReportUserRequest, OctopusGrpcModels.Com_Octopuscommunity_ReportUserResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeBlockUserInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_BlockUserRequest, OctopusGrpcModels.Com_Octopuscommunity_BlockUserResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeGetJwtFromClientSignedTokenInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_GetJwtFromClientSignedTokenRequest, OctopusGrpcModels.Com_Octopuscommunity_GetJwtFromClientSignedTokenResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makecreateUserInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_CreateUserRequest, OctopusGrpcModels.Com_Octopuscommunity_CreateUserResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeCreateProfileInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_UpdateProfileRequest, OctopusGrpcModels.Com_Octopuscommunity_UpdateProfileResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }
}
