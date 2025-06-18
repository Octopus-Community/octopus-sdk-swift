//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import Combine
import os
import OctopusDependencyInjection

extension Injected {
    static let notificationSettingsDatabase = Injector.InjectedIdentifier<NotificationSettingsDatabase>()
}

class NotificationSettingsDatabase: InjectableObject {
    static let injectedIdentifier = Injected.notificationSettingsDatabase

    private let context: NSManagedObjectContext

    init(injector: Injector) {
        let coreDataStack = injector.getInjected(identifiedBy: Injected.modelCoreDataStack)
        context = coreDataStack.saveContext
    }

    func notificationSettingsPublisher() -> AnyPublisher<NotificationSettings?, Error> {
        (context
            .publisher(request: NotificationSettingsEntity.fetchOne()) {
                return $0.map { NotificationSettings(from: $0) }
            } as AnyPublisher<[NotificationSettings], Error>
        )
        .map(\.first)
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }

    func upsert(settings: NotificationSettings) async throws {
        try await context.performAsync { [context] in
            let notificationSettingsEntity: NotificationSettingsEntity
            if let existingSettings = try context.fetch(NotificationSettingsEntity.fetchOne()).first {
                notificationSettingsEntity = existingSettings
            } else {
                notificationSettingsEntity = NotificationSettingsEntity(context: context)
            }
            notificationSettingsEntity.pushNotificationsEnabled = settings.pushNotificationsEnabled

            try context.save()
        }
    }
}

