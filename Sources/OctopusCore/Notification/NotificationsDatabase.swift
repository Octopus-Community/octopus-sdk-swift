//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import Combine
import os
import OctopusDependencyInjection

extension Injected {
    static let notificationsDatabase = Injector.InjectedIdentifier<NotificationsDatabase>()
}

class NotificationsDatabase: InjectableObject {
    static let injectedIdentifier = Injected.notificationsDatabase

    private let context: NSManagedObjectContext

    init(injector: Injector) {
        let coreDataStack = injector.getInjected(identifiedBy: Injected.modelCoreDataStack)
        context = coreDataStack.saveContext
    }

    func notificationsPublisher() -> AnyPublisher<[OctoNotification], Error> {
        (context
            .publisher(request: NotificationEntity.fetchAllSorted()) {
                return $0.map { OctoNotification(from: $0) }
            } as AnyPublisher<[OctoNotification], Error>
        )
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }

    func replaceAll(notifications: [OctoNotification]) async throws {
        try await context.performAsync { [context] in

            // first delete all existing root feeds
            let deleteRequest: NSFetchRequest<NSFetchRequestResult> = NotificationEntity.fetchAll() as! NSFetchRequest<NSFetchRequestResult>
            deleteRequest.includesPropertyValues = false
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: deleteRequest)
            try context.execute(batchDeleteRequest)

            for (index, notification) in notifications.enumerated() {
                let notifEntity = NotificationEntity(context: context)

                notifEntity.uuid = notification.uuid
                notifEntity.position = index
                notifEntity.updateTimestamp = notification.updateDate.timeIntervalSince1970
                notifEntity.isRead = notification.isRead
                notifEntity.text = notification.text
                notifEntity.openAction = notification.openAction

                notifEntity.thumbnailsRelationship = NSOrderedSet(array: notification.thumbnails.map {
                    switch $0 {
                    case let .profile(profile):
                        let profileEntity = MinimalProfileEntity(context: context)
                        profileEntity.profileId = profile.uuid
                        profileEntity.nickname = profile.nickname
                        profileEntity.avatarUrl = profile.avatarUrl
                        return profileEntity
                    }
                })
            }

            try context.save()
        }
    }

    func markAsRead(ids: [String]) async throws {
        try await context.performAsync { [context] in
            let request = NotificationEntity.fetchAllByIds(ids: ids)
            let notifications = try context.fetch(request)

            for notification in notifications {
                notification.isRead = true
            }
            
            try context.save()
        }
    }
}

