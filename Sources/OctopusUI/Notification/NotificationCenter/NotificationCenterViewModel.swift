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
    @Published private(set) var showPushNotificationSetting = false
    @Published var pushNotificationEnabled = false
    @Published private(set) var notifications: [DisplayableNotification] = []

    // for errors that are caused by an action inside the view (i.e. not refreshs)
    @Published var displayableError: DisplayableString?

    let octopus: OctopusSDK
    private var storage = [AnyCancellable]()
    private var viewIsDisplayed = false
    private var modelPushNotificationEnabled = false

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

        octopus.core.notificationsRepository.$canHandlePushNotifications
            .sink { [unowned self] in
                showPushNotificationSetting = $0
            }.store(in: &storage)

        octopus.core.notificationsRepository.getSettings()
            .replaceError(with: .defaultValue)
            .sink { [unowned self] in
                modelPushNotificationEnabled = $0.pushNotificationsEnabled
                pushNotificationEnabled = $0.pushNotificationsEnabled
            }.store(in: &storage)

        $pushNotificationEnabled.sink { [unowned self] in
            guard $0 != modelPushNotificationEnabled else { return }
            setPushNotificationEnabled($0)
        }.store(in: &storage)

        Task {
            try? await fetchNotificationSettings()
        }
    }

    func viewDidAppear() {
        viewIsDisplayed = true
        Task {
            try? await fetchNotifications()
        }
    }

    func viewDidDisappear() {
        viewIsDisplayed = false
        markAllNotifWithoutActionAsRead()
    }

    func refresh() async throws(ServerCallError) {
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { [self] in try await fetchNotificationSettings() }
                if viewIsDisplayed {
                    group.addTask { [self] in try await fetchNotifications() }
                }

                try await group.waitForAll()
            }
        } catch {
            if let error = error as? ServerCallError {
                throw error
            } else {
                throw .other(error)
            }
        }
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

    private func fetchNotifications() async throws(ServerCallError) {
        do {
            try await octopus.core.notificationsRepository.fetchNotifications()
        } catch {
            if #available(iOS 14, *) { Logger.notifs.debug("Error while trying to fetch notifications: \(error)") }
            throw error
        }
    }

    private func markNotifsAsRead(ids: [String]) async {
        do {
            try await octopus.core.notificationsRepository.markNotificationsAsRead(notifIds: ids)
        } catch {
            if #available(iOS 14, *) { Logger.notifs.debug("Error while marking notifications as read: \(error)") }
        }
    }

    private func fetchNotificationSettings() async throws(ServerCallError) {
        do {
            try await octopus.core.notificationsRepository.fetchSetting()
        } catch {
            if #available(iOS 14, *) { Logger.notifs.debug("Error while trying to fetch settings: \(error)") }
            throw error
        }
    }

    private func setPushNotificationEnabled(_ enabled: Bool) {
        Task {
            await setPushNotificationEnabled(enabled)
        }
    }

    private func setPushNotificationEnabled(_ enabled: Bool) async {
        do {
            try await octopus.core.notificationsRepository.set(
                settings: NotificationSettings(pushNotificationsEnabled: enabled))
        } catch {
            pushNotificationEnabled = modelPushNotificationEnabled
            try? await fetchNotificationSettings() // fetch the latest value from the server
            self.displayableError = error.displayableMessage
        }
    }

}
