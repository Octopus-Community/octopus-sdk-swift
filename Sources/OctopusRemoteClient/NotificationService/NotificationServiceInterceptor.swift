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

final class NotificationServiceInterceptor: Com_Octopuscommunity_NotificationServiceClientInterceptorFactoryProtocol, @unchecked Sendable {
    private let getUserIdBlock: () -> String?
    private let updateTokenBlock: (String) -> Void

    init(getUserIdBlock: @escaping () -> String?, updateTokenBlock: @escaping (String) -> Void) {
        self.getUserIdBlock = getUserIdBlock
        self.updateTokenBlock = updateTokenBlock
    }

    func makeGetUserNotificationsInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_GetUserNotificationsRequest, OctopusGrpcModels.Com_Octopuscommunity_GetUserNotificationsResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeMarkNotificationsAsReadInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_MarkNotificationsAsReadRequest, OctopusGrpcModels.Com_Octopuscommunity_MarkNotificationsAsReadResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeRegisterPushTokenInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_RegisterPushTokenRequest, OctopusGrpcModels.Com_Octopuscommunity_RegisterPushTokenResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeSetNotificationSettingsInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_SetNotificationSettingsRequest, OctopusGrpcModels.Com_Octopuscommunity_NotificationSettingsResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeGetNotificationSettingsInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_GetNotificationSettingsRequest, OctopusGrpcModels.Com_Octopuscommunity_NotificationSettingsResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeSendCommunityNotificationInterceptors() -> [ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_SendCommunityNotificationRequest, OctopusGrpcModels.Com_Octopuscommunity_SendCommunityNotificationResponse>] {
        [RefreshingTokenInterceptor(getUserId: getUserIdBlock, updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }
}
