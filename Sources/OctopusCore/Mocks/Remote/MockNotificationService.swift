//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusRemoteClient
import OctopusGrpcModels

class MockNotificationService: NotificationService {
    /// Fifo of the responses to `getUserNotifications`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var getNotifsResponses = [Com_Octopuscommunity_GetUserNotificationsResponse]()

    /// Fifo of the responses to `markNotificationsAsRead`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private var markNotificationsAsReadResponses = [Com_Octopuscommunity_MarkNotificationsAsReadResponse]()

    /// Fifo of the responses to `registerPushToken`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private(set) var registerPushTokenResponses = [Com_Octopuscommunity_RegisterPushTokenResponse]()

    /// Fifo of the responses to `getNotificationsSettings`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private(set) var getNotificationsSettingsResponses = [Com_Octopuscommunity_NotificationSettingsResponse]()

    /// Fifo of the responses to `setNotificationsSettings`.
    /// Element to use is the last one (i.e insertion at 0, pop at count - 1)
    private(set) var setNotificationsSettingsResponses = [Com_Octopuscommunity_NotificationSettingsResponse]()

    init() { }

    func getUserNotifications(userId: String, authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError) -> Com_Octopuscommunity_GetUserNotificationsResponse {
        guard let response = getNotifsResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextGetNotifs must be called before"))
        }
        return response
    }

    func markNotificationsAsRead(
        notificationIds: [String],
        authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_MarkNotificationsAsReadResponse {
        guard let response = markNotificationsAsReadResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextMarkNotifAsRead must be called before"))
        }
        return response
    }

    func registerPushToken(
        deviceToken: String, isSandbox: Bool,
        authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError) -> Com_Octopuscommunity_RegisterPushTokenResponse {
        guard let response = registerPushTokenResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextRegisterPushToken must be called before"))
        }
        return response
    }

    func getNotificationsSettings(authenticationMethod: AuthenticationMethod) async throws(RemoteClientError)
    -> Com_Octopuscommunity_NotificationSettingsResponse {
        guard let response = getNotificationsSettingsResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextGetNotificationsSettings must be called before"))
        }
        return response
    }

    func setNotificationsSettings(enablePushNotification: Bool, authenticationMethod: AuthenticationMethod)
    async throws(RemoteClientError)
    -> Com_Octopuscommunity_NotificationSettingsResponse {
        guard let response = setNotificationsSettingsResponses.popLast() else {
            throw .unknown(MockError("Dev error, injectNextSetNotificationsSettings must be called before"))
        }
        return response
    }
}

extension MockNotificationService {
    func injectNextGetNotifs(_ response: Com_Octopuscommunity_GetUserNotificationsResponse) {
        getNotifsResponses.insert(response, at: 0)
    }

    func injectNextMarkNotifAsRead(_ response: Com_Octopuscommunity_MarkNotificationsAsReadResponse) {
        markNotificationsAsReadResponses.insert(response, at: 0)
    }

    func injectNextRegisterPushToken(_ response: Com_Octopuscommunity_RegisterPushTokenResponse) {
        registerPushTokenResponses.insert(response, at: 0)
    }

    func injectNextGetNotificationsSettings(_ response: Com_Octopuscommunity_NotificationSettingsResponse) {
        getNotificationsSettingsResponses.insert(response, at: 0)
    }

    func injectNextSetNotificationsSettings(_ response: Com_Octopuscommunity_NotificationSettingsResponse) {
        setNotificationsSettingsResponses.insert(response, at: 0)
    }
}
