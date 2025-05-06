//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import GRPC
import OctopusGrpcModels

final class NotificationServiceInterceptor: Com_Octopuscommunity_NotificationServiceClientInterceptorFactoryProtocol, @unchecked Sendable {
    private let updateTokenBlock: (String) -> Void

    init(updateTokenBlock: @escaping (String) -> Void) {
        self.updateTokenBlock = updateTokenBlock
    }

    func makeGetUserNotificationsInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_GetUserNotificationsRequest, OctopusGrpcModels.Com_Octopuscommunity_GetUserNotificationsResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }

    func makeMarkNotificationsAsReadInterceptors() -> [GRPC.ClientInterceptor<OctopusGrpcModels.Com_Octopuscommunity_MarkNotificationsAsReadRequest, OctopusGrpcModels.Com_Octopuscommunity_MarkNotificationsAsReadResponse>] {
        [RefreshingTokenInterceptor(updateTokenBlock: updateTokenBlock), LoggingInterceptor()]
    }
}
