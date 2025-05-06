//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import OctopusDependencyInjection
import OctopusRemoteClient
import OctopusGrpcModels

extension Injected {
    static let notificationsRepository = Injector.InjectedIdentifier<NotificationsRepository>()
}

public class NotificationsRepository: InjectableObject, @unchecked Sendable {
    public static let injectedIdentifier = Injected.notificationsRepository

    private let notificationsDatabase: NotificationsDatabase
    private let authCallProvider: AuthenticatedCallProvider
    private let remoteClient: OctopusRemoteClient
    private let connectionRepository: ConnectionRepository
    private let profileRepository: ProfileRepository


    init(injector: Injector) {
        notificationsDatabase = injector.getInjected(identifiedBy: Injected.notificationsDatabase)
        authCallProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        connectionRepository = injector.getInjected(identifiedBy: Injected.connectionRepository)
        profileRepository = injector.getInjected(identifiedBy: Injected.profileRepository)
    }

    public func getNotifications() -> AnyPublisher<[OctoNotification], Error> {
        return notificationsDatabase.notificationsPublisher()
    }

    public func fetchNotifications() async throws(ServerCallError) {
        guard case let .connected(user) = connectionRepository.connectionState else {
            throw .other(InternalError.incorrectState)
        }
        do {
            let response = try await remoteClient.notificationService.getUserNotifications(
                userId: user.profile.userId,
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
        try await notificationsDatabase.markAsRead(ids: notifIds)
        _ = try await remoteClient.notificationService.markNotificationsAsRead(
            notificationIds: notifIds,
            authenticationMethod: try authCallProvider.authenticatedMethod())
    }
}
