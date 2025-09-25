//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import Combine
import OctopusDependencyInjection

extension Injected {
    static let userConfigDatabase = Injector.InjectedIdentifier<UserConfigDatabase>()
}

class UserConfigDatabase: InjectableObject {
    static let injectedIdentifier = Injected.userConfigDatabase

    private let context: NSManagedObjectContext

    init(injector: Injector) {
        let coreDataStack = injector.getInjected(identifiedBy: Injected.configCoreDataStack)
        context = coreDataStack.saveContext
    }

    func configPublisher() -> AnyPublisher<UserConfig?, Error> {
        (context
            .publisher(request: UserConfigEntity.fetch()) {
                guard let configEntity = $0.first, let config = UserConfig(from: configEntity) else { return [] }
                return [config]
            } as AnyPublisher<[UserConfig], Error>
        )
        .map(\.first)
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }

    func upsert(canAccessCommunity: Bool, message: String?) async throws {
        try await context.performAsync { [context] in
            let configEntity: UserConfigEntity
            if let existingConfig = try context.fetch(UserConfigEntity.fetch()).first {
                configEntity = existingConfig
            } else {
                configEntity = UserConfigEntity(context: context)
            }
            configEntity.fill(canAccessCommunity: canAccessCommunity, message: message, context: context)

            try context.save()
        }
    }

    func deleteConfig() async throws {
        try await context.performAsync { [context] in
            if let existingConfig = try context.fetch(UserConfigEntity.fetch()).first {
                context.delete(existingConfig)
            }
            try context.save()
        }
    }
}
