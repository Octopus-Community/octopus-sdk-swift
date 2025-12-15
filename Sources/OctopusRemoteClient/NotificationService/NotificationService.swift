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

public protocol NotificationService {
    func getUserNotifications(
        userId: String,
        authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_GetUserNotificationsResponse

    func markNotificationsAsRead(
        notificationIds: [String],
        authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_MarkNotificationsAsReadResponse

    func registerPushToken(
        deviceToken: String, isSandbox: Bool,
        authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_RegisterPushTokenResponse

    func getNotificationsSettings(authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_NotificationSettingsResponse

    func setNotificationsSettings(enablePushNotification: Bool, authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError)
    -> Com_Octopuscommunity_NotificationSettingsResponse
}

class NotificationServiceClient: ServiceClient, NotificationService {
    private let client: Com_Octopuscommunity_NotificationServiceAsyncClient


    init(unaryChannel: GRPCChannel, apiKey: String, sdkVersion: String, installId: String,
         getUserIdBlock: @escaping () -> String?,
         updateTokenBlock: @escaping (String) -> Void) {
        client = Com_Octopuscommunity_NotificationServiceAsyncClient(
            channel: unaryChannel, interceptors: NotificationServiceInterceptor(
                getUserIdBlock: getUserIdBlock, updateTokenBlock: updateTokenBlock))
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

    func registerPushToken(
        deviceToken: String, isSandbox: Bool,
        authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_RegisterPushTokenResponse {
        let request = Com_Octopuscommunity_RegisterPushTokenRequest.with {
            $0.pushToken = deviceToken
            $0.isSandbox = isSandbox
        }
        return try await callRemote(authenticationMethod) {
            try await client.registerPushToken(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }

    func getNotificationsSettings(authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_NotificationSettingsResponse {
        let request = Com_Octopuscommunity_GetNotificationSettingsRequest()
        return try await callRemote(authenticationMethod) {
            try await client.getNotificationSettings(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }

    func setNotificationsSettings(enablePushNotification: Bool, authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError)
    -> Com_Octopuscommunity_NotificationSettingsResponse {
        let request = Com_Octopuscommunity_SetNotificationSettingsRequest.with {
            $0.settings = .with {
                $0.pushNotificationEnabled = enablePushNotification
            }
        }
        return try await callRemote(authenticationMethod) {
            try await client.setNotificationSettings(
                request, callOptions: getCallOptions(authenticationMethod: authenticationMethod))
        }
    }
}
