//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import GRPC
import GrpcModels

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

    func makeBanUserInterceptors() -> [GRPC.ClientInterceptor<GrpcModels.Com_Octopuscommunity_BanUserRequest, GrpcModels.Com_Octopuscommunity_BanUserResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeDeleteMyProfileInterceptors() -> [GRPC.ClientInterceptor<GrpcModels.Com_Octopuscommunity_DeleteMyProfileRequest, GrpcModels.Com_Octopuscommunity_DeleteMyProfileResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeUnbanUserInterceptors() -> [GRPC.ClientInterceptor<GrpcModels.Com_Octopuscommunity_UnbanUserRequest, GrpcModels.Com_Octopuscommunity_UnbanUserResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeReportUserInterceptors() -> [GRPC.ClientInterceptor<GrpcModels.Com_Octopuscommunity_ReportUserRequest, GrpcModels.Com_Octopuscommunity_ReportUserResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeBlockUserInterceptors() -> [GRPC.ClientInterceptor<GrpcModels.Com_Octopuscommunity_BlockUserRequest, GrpcModels.Com_Octopuscommunity_BlockUserResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeGetJwtFromClientSignedTokenInterceptors() -> [GRPC.ClientInterceptor<GrpcModels.Com_Octopuscommunity_GetJwtFromClientSignedTokenRequest, GrpcModels.Com_Octopuscommunity_GetJwtFromClientSignedTokenResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }
}
