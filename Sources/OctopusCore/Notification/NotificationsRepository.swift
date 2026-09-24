//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import UserNotifications
import OctopusDependencyInjection
import OctopusRemoteClient
import OctopusGrpcModels
import os

extension Injected {
    static let notificationsRepository = Injector.InjectedIdentifier<NotificationsRepository>()
}

public class NotificationsRepository: InjectableObject, @unchecked Sendable {
    public static let injectedIdentifier = Injected.notificationsRepository

    /// Whether the client of the SDK is providing everything to support Push Notifications and if user has enabled
    /// push notif permissions for this app
    @Published public private(set) var canHandlePushNotifications: Bool = false

    public private(set) var latestNotificationDeviceToken: String?

    private let notificationsDatabase: NotificationsDatabase
    private let settingsDatabase: NotificationSettingsDatabase
    private let authCallProvider: AuthenticatedCallProvider
    private let remoteClient: OctopusRemoteClient
    private let profileRepository: ProfileRepository
    private let networkMonitor: NetworkMonitor
    private let appStateMonitor: AppStateMonitor
    /// The notification center
    private let notifCenter: UserNotificationCenterProvider

    private var registerPushTokenCancellable: AnyCancellable?

    @UserDefault(key: "OctopusSDK.Notifications.DeviceTokenSetOnce", defaultValue: false)
    private(set) var storedDeviceTokenSetOnce: Bool!

    @Published private var deviceTokenSetOnce: Bool
    @Published private var pushNotifPermissionGranted = false // real value will be set in init
    private var lastPushNotifPermissionGrantedUpdateTask: Task<Void, Never> = Task {}
    private var storage = [AnyCancellable]()

    private static let pnAdditionalDataKey = "data"
    private static let pnIsOctopusKey = "is_octopus_notification"
    private static let pnLinkPathKey = "link_path"

    init(injector: Injector) {
        notificationsDatabase = injector.getInjected(identifiedBy: Injected.notificationsDatabase)
        settingsDatabase = injector.getInjected(identifiedBy: Injected.notificationSettingsDatabase)
        authCallProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        profileRepository = injector.getInjected(identifiedBy: Injected.profileRepository)
        networkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor)
        appStateMonitor = injector.getInjected(identifiedBy: Injected.appStateMonitor)
        notifCenter = injector.getInjected(identifiedBy: Injected.userNotificationCenter)

        // set it to false only to correctly init the repository. It is set with the correct value right after
        deviceTokenSetOnce = false
        deviceTokenSetOnce = storedDeviceTokenSetOnce

        // Listen to the app state in order to update the push notification permission infos
        appStateMonitor.appStatePublisher
            .removeDuplicates()
            .sink { [unowned self] in
                guard $0 == .active else { return }
                updatePushNotifPermissionGranted()
        }.store(in: &storage)

        // whenever the `deviceTokenSetOnce` value changes, updated its stored value
        $deviceTokenSetOnce.sink { [unowned self] in
            guard $0 != storedDeviceTokenSetOnce else { return }
            storedDeviceTokenSetOnce = $0
        }.store(in: &storage)

        // When the push notification permission infos and the deviceTokenSetOnce changes,
        // update the canHandlePushNotifications.
        // Both inputs are moved onto the main queue before being combined, because they are written from
        // different threads: `pushNotifPermissionGranted` on the main actor, `deviceTokenSetOnce` on
        // whichever thread calls `set(notificationDeviceToken:)`. `CombineLatest` stores an incoming value
        // under its lock but delivers the combination after releasing it, so two values arriving at once can
        // be delivered in the wrong order and leave the result latched on the stale pair — here, "permission
        // granted but no device token" once both are actually true, with no further input to correct it.
        // Feeding it from a single queue removes that concurrency; delivering on the main queue also keeps
        // the UI observers of `canHandlePushNotifications` on the main thread.
        Publishers.CombineLatest(
            $pushNotifPermissionGranted.removeDuplicates().receive(on: DispatchQueue.main),
            $deviceTokenSetOnce.removeDuplicates().receive(on: DispatchQueue.main)
        )
        // weak, not unowned: delivery is asynchronous now, so it can outlive this repository
        .sink { [weak self] pushNotifPermissionGranted, deviceTokenSetOnce in
            self?.canHandlePushNotifications = pushNotifPermissionGranted && deviceTokenSetOnce
        }.store(in: &storage)
    }

    private func updatePushNotifPermissionGranted() {
        // Capture the current last task before starting the new one
        let previousTask = lastPushNotifPermissionGrantedUpdateTask

        lastPushNotifPermissionGrantedUpdateTask = Task { [weak self] in
            await previousTask.value
            guard let self else { return }
            let authorizationStatus = await notifCenter.authorizationStatus()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.pushNotifPermissionGranted = switch authorizationStatus {
                case .authorized, .provisional, .ephemeral: true
                case .notDetermined, .denied: false
                @unknown default: true // if there is an unknown value, consider it as true
                }
            }
        }
    }

    // MARK: Internal Notifications
    public func getNotifications() -> AnyPublisher<[OctoNotification], Never> {
        return notificationsDatabase.notificationsPublisher()
    }

    public func fetchNotifications() async throws(ServerCallError) {
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        guard let profile = profileRepository.profile else {
            throw .other(InternalError.incorrectState)
        }
        do {
            let response = try await remoteClient.notificationService.getUserNotifications(
                userId: profile.userId,
                authenticationMethod: try authCallProvider.authenticatedMethod())
            let notifications = response.notifications.map { OctoNotification(from: $0) }
            try await notificationsDatabase.replaceAll(notifications: notifications)
            try await profileRepository.resetNotificationBadgeCount()
        } catch {
            if let error = error as? RemoteClientError {
                throw .serverError(ServerError(remoteClientError: error))
            } else {
                throw .other(error)
            }
        }
    }

    public func markNotificationsAsRead(notifIds: [String]) async throws {
        guard !notifIds.isEmpty else { return }
        try await notificationsDatabase.markAsRead(ids: notifIds)
        _ = try await remoteClient.notificationService.markNotificationsAsRead(
            notificationIds: notifIds,
            authenticationMethod: try authCallProvider.authenticatedMethod())
    }

    // MARK: Settings

    public func getSettings() -> AnyPublisher<NotificationSettings, Never> {
        return settingsDatabase.notificationSettingsPublisher()
            .replaceNil(with: .defaultValue)
            .eraseToAnyPublisher()
    }

    public func fetchSetting() async throws(ServerCallError) {
        guard networkMonitor.connectionAvailable else {
            throw .noNetwork
        }
        do {
            let response = try await remoteClient.notificationService.getNotificationsSettings(
                authenticationMethod: try authCallProvider.authenticatedMethod())
            try await settingsDatabase.upsert(settings: NotificationSettings(from: response))
        } catch {
            if let error = error as? RemoteClientError {
                throw .serverError(ServerError(remoteClientError: error))
            } else {
                throw .other(error)
            }
        }
    }

    public func set(settings: NotificationSettings) async throws(AuthenticatedActionError) {
        guard networkMonitor.connectionAvailable else {
            throw .noNetwork
        }
        do {
            let serverSettings = try await remoteClient.notificationService
                .setNotificationsSettings(enablePushNotification: settings.pushNotificationsEnabled,
                                          authenticationMethod: try authCallProvider.authenticatedMethod())
            try await settingsDatabase.upsert(settings: NotificationSettings(from: serverSettings))
        } catch {
            if let error = error as? AuthenticatedActionError {
                throw error
            } else if let error = error as? RemoteClientError {
                throw .serverError(ServerError(remoteClientError: error))
            } else {
                throw .other(error)
            }
        }
    }

    // MARK: Push Notifications
    public static func isAnOctopusNotification(userInfo: [AnyHashable: Any]) -> Bool {
        getAdditionnalData(userInfo: userInfo)?[Self.pnIsOctopusKey] != nil
    }

    public func set(notificationDeviceToken: String) {
        latestNotificationDeviceToken = notificationDeviceToken
        deviceTokenSetOnce = true
        updatePushNotifPermissionGranted()
        // Each time a new profile is present (even null profile), as soon as there is internet, send the token
        registerPushTokenCancellable = profileRepository.profilePublisher
            .removeDuplicates { $0?.userId == $1?.userId } // only focus on the user id
            .map { [unowned self] _ in
                return networkMonitor.connectionAvailablePublisher
                    .filter { $0 }
                    .first()
                    .eraseToAnyPublisher()
            }
            .switchToLatest()
            .filter { $0 }
            .sink { [unowned self] _ in
                registerPushToken(notificationDeviceToken: notificationDeviceToken)
            }
    }

    public func getPushNotificationTappedAction(userInfo: [AnyHashable: Any])
    -> NotifAction? {
        guard let pnInfos = Self.getAdditionnalData(userInfo: userInfo) else { return nil }
        if let link = pnInfos[Self.pnLinkPathKey] as? String,
           let contentsToOpen: [NotifAction.OctoScreen] = .init(from: link).nilIfEmpty {
            return .open(path: contentsToOpen)
        }
        return nil
    }

    private func registerPushToken(notificationDeviceToken: String) {
        Task {
            await registerPushToken(notificationDeviceToken: notificationDeviceToken)
        }
    }

    private func registerPushToken(notificationDeviceToken: String) async {
        do {
            if #available(iOS 14, *) { Logger.notifs.trace("Registering notification device token") }
            let isSandbox = await Self.isSandboxEnvironment()
            _ = try await remoteClient.notificationService.registerPushToken(
                deviceToken: notificationDeviceToken, isSandbox: isSandbox,
                authenticationMethod: authCallProvider.authenticatedIfPossibleMethod())
        } catch {
            if #available(iOS 14, *) { Logger.notifs.debug("Error when registering push token: \(error)") }
        }
    }

    private static func getAdditionnalData(userInfo: [AnyHashable: Any]) -> [String: Any]? {
        return userInfo[Self.pnAdditionalDataKey] as? [String: Any]
    }

    private static func isSandboxEnvironment() async -> Bool {
#if targetEnvironment(simulator)
        return true
#else
        // Read the embedded.mobileprovision to know if we are in Sandbox env or not.
        guard let provisionningProfile = ProvisionningProfile.read() else { return false }
        return provisionningProfile.entitlements.apsEnvironment == .development
#endif
    }
}
