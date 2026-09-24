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
    /// Set when the first load fails with no notification listed yet.
    @Published private(set) var loadFailure: ScreenStateFailure?
    /// Until the first load settles, an empty list means "still loading", not "nothing to show".
    @Published private(set) var hasLoadedOnce = false

    let octopus: OctopusSDK
    private var storage = [AnyCancellable]()
    private var viewIsDisplayed = false
    private var modelPushNotificationEnabled = false

    private var relativeDateFormatterProvider: RelativeDateTimeFormatterProvider

    init(octopus: OctopusSDK) {
        self.octopus = octopus
        relativeDateFormatterProvider = RelativeDateTimeFormatterProvider(octopus: octopus)

        octopus.core.notificationsRepository.getNotifications()
            .sink { [unowned self] in
                notifications = $0.map {
                    DisplayableNotification(notification: $0, dateFormatter: relativeDateFormatterProvider.formatter)
                }
            }.store(in: &storage)

        octopus.core.notificationsRepository.$canHandlePushNotifications
            .sink { [unowned self] in
                showPushNotificationSetting = $0
            }.store(in: &storage)

        octopus.core.notificationsRepository.getSettings()
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
            await loadNotifications()
        }
    }

    /// Re-runs the first load after a failure.
    func retryFirstLoad() {
        loadFailure = nil
        // Hold the loader until the retry settles, instead of flashing the empty state through the gap.
        hasLoadedOnce = false
        Task {
            await loadNotifications()
        }
    }

    private func loadNotifications() async {
        do {
            try await fetchNotifications()
            loadFailure = nil
        } catch {
            // Nothing listed yet: the error takes the list's place, with a retry. Otherwise a toast says
            // so without hiding the notifications already read (Screen states spec).
            if notifications.isEmpty {
                loadFailure = ScreenStateFailure(error)
            } else if case .noNetwork = error {
                octopus.core.toastsRepository.display(errorToast: .noNetwork)
            } else {
                octopus.core.toastsRepository.display(errorToast: .unknown)
            }
        }
        hasLoadedOnce = true
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
        guard !notReadNotificationsWithoutAction.isEmpty else { return }
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
