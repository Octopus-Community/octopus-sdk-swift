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

final class UserServiceInterceptor: Com_Octopuscommunity_UserServiceClientInterceptorFactoryProtocol, @unchecked Sendable {
    private let getUserIdBlock: () -> String?
    private let updateTokenBlock: (String) -> Void

    init(getUserIdBlock: @escaping () -> String?, updateTokenBlock: @escaping (String) -> Void) {
        self.getUserIdBlock = getUserIdBlock
        self.updateTokenBlock = updateTokenBlock
    }

    func makeDeleteUserInterceptors() -> [ClientInterceptor<Com_Octopuscommunity_DeleteUserRequest, Com_Octopuscommunity_DeleteUserResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeUpdateProfileInterceptors() -> [ClientInterceptor<Com_Octopuscommunity_UpdateProfileRequest, Com_Octopuscommunity_UpdateProfileResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeGetPublicProfileInterceptors() -> [ClientInterceptor<Com_Octopuscommunity_GetPublicProfileRequest, Com_Octopuscommunity_GetPublicProfileResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeGetPrivateProfileInterceptors() -> [ClientInterceptor<Com_Octopuscommunity_GetPrivateProfileRequest, Com_Octopuscommunity_GetPrivateProfileResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeBanUserInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_BanUserRequest, OctopusGrpcModels.Com_Octopuscommunity_BanUserResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeDeleteMyProfileInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_DeleteMyProfileRequest, OctopusGrpcModels.Com_Octopuscommunity_DeleteMyProfileResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeUnbanUserInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_UnbanUserRequest, OctopusGrpcModels.Com_Octopuscommunity_UnbanUserResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeReportUserInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_ReportUserRequest, OctopusGrpcModels.Com_Octopuscommunity_ReportUserResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeBlockUserInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_BlockUserRequest, OctopusGrpcModels.Com_Octopuscommunity_BlockUserResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeGetJwtFromClientSignedTokenInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_GetJwtFromClientSignedTokenRequest, OctopusGrpcModels.Com_Octopuscommunity_GetJwtFromClientSignedTokenResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makecreateUserInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_CreateUserRequest, OctopusGrpcModels.Com_Octopuscommunity_CreateUserResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeCreateProfileInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_UpdateProfileRequest, OctopusGrpcModels.Com_Octopuscommunity_UpdateProfileResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeGetGuestJwtInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_GetGuestJwtRequest, OctopusGrpcModels.Com_Octopuscommunity_GetGuestJwtResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeCanAccessCommunityInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_CanAccessCommunityRequest, OctopusGrpcModels.Com_Octopuscommunity_CanAccessCommunityResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeByPassAbTestingInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_ByPassAbTestingRequest, OctopusGrpcModels.Com_Octopuscommunity_ByPassAbTestingResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeShadowBanUserInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_ShadowBanUserRequest, OctopusGrpcModels.Com_Octopuscommunity_ShadowBanUserResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeUnShadowBanUserInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_ShadowUnbanUserRequest, OctopusGrpcModels.Com_Octopuscommunity_UnShadowBanUserResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeSearchUserInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_SearchUserRequest, OctopusGrpcModels.Com_Octopuscommunity_SearchUserResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeSetProfileTagInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_SetProfileTagRequest, OctopusGrpcModels.Com_Octopuscommunity_SetProfileTagResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeEnteringOctopusInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_EnteringOctopusRequest, OctopusGrpcModels.Com_Octopuscommunity_EnteringOctopusResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }
}
