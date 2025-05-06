//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus
import OctopusCore
import os

@MainActor
class NotificationCenterViewModel: ObservableObject {
    @Published private(set) var notifications: [DisplayableNotification] = []

    let octopus: OctopusSDK
    private var storage = [AnyCancellable]()
    private var viewIsDisplayed = false

    private var relativeDateFormatter: RelativeDateTimeFormatter = {
        let relativeDateFormatter = RelativeDateTimeFormatter()
        relativeDateFormatter.dateTimeStyle = .numeric
        relativeDateFormatter.unitsStyle = .short

        return relativeDateFormatter
    }()

    init(octopus: OctopusSDK) {
        self.octopus = octopus

        octopus.core.notificationsRepository.getNotifications()
            .replaceError(with: [])
            .sink { [unowned self] in
                notifications = $0.map {
                    DisplayableNotification(notification: $0, dateFormatter: relativeDateFormatter)
                }
            }.store(in: &storage)
    }

    func viewDidAppear() {
        viewIsDisplayed = true
        Task {
            await fetchNotifications()
        }
    }

    func viewDidDisappear() {
        viewIsDisplayed = false
        markAllNotifWithoutActionAsRead()
    }

    func refresh() async {
        guard viewIsDisplayed else { return }
        await fetchNotifications()
    }

    func markNotificationAsRead(notifId: String) {
        Task {
            await markNotifsAsRead(ids: [notifId])
        }
    }

    private func markAllNotifWithoutActionAsRead() {
        let notReadNotificationsWithoutAction = notifications.compactMap { notif -> String? in
            guard notif.action == nil, !notif.isRead else { return nil }
            return notif.uuid
        }
        Task {
            await markNotifsAsRead(ids: notReadNotificationsWithoutAction)
        }
    }

    private func fetchNotifications() async {
        do {
            try await octopus.core.notificationsRepository.fetchNotifications()
        } catch {
            if #available(iOS 14, *) { Logger.notifs.debug("Error while trying to fetch notifications: \(error)") }
        }
    }

    private func markNotifsAsRead(ids: [String]) async {
        do {
            try await octopus.core.notificationsRepository.markNotificationsAsRead(notifIds: ids)
        } catch {
            if #available(iOS 14, *) { Logger.notifs.debug("Error while marking notifications as read: \(error)") }
        }
    }

}
