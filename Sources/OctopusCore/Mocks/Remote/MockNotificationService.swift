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
}

extension MockNotificationService {
    func injectNextGetNotifs(_ response: Com_Octopuscommunity_GetUserNotificationsResponse) {
        getNotifsResponses.insert(response, at: 0)
    }

    func injectNextMarkNotifAsRead(_ response: Com_Octopuscommunity_MarkNotificationsAsReadResponse) {
        markNotificationsAsReadResponses.insert(response, at: 0)
    }
}
