//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import GRPC
import OctopusGrpcModels
import Logging

public protocol NotificationService {
    func getUserNotifications(
        userId: String,
        authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetUserNotificationsResponse

    func markNotificationsAsRead(
        notificationIds: [String],
        authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_MarkNotificationsAsReadResponse
}

class NotificationServiceClient: ServiceClient, NotificationService {
    private let client: Com_Octopuscommunity_NotificationServiceAsyncClient


    init(unaryChannel: GRPCChannel, apiKey: String, sdkVersion: String, installId: String,
         updateTokenBlock: @escaping (String) -> Void) {
        client = Com_Octopuscommunity_NotificationServiceAsyncClient(
            channel: unaryChannel, interceptors: NotificationServiceInterceptor(updateTokenBlock: updateTokenBlock))
        super.init(apiKey: apiKey, sdkVersion: sdkVersion, installId: installId)
    }

    func getUserNotifications(
        userId: String,
        authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetUserNotificationsResponse {
        let request = Com_Octopuscommunity_GetUserNotificationsRequest.with {
            $0.userID = userId
        }
        return try await callRemote(authenticationMethod) {
            try await client.getUserNotifications(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))

        }
    }

    func markNotificationsAsRead(
        notificationIds: [String],
        authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_MarkNotificationsAsReadResponse {
        let request = Com_Octopuscommunity_MarkNotificationsAsReadRequest.with {
            $0.notificationIds = notificationIds
        }
        return try await callRemote(authenticationMethod) {
            try await client.markNotificationsAsRead(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))

        }
    }
}
