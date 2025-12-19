//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import Combine
import OctopusDependencyInjection

extension Injected {
    static let communityConfigDatabase = Injector.InjectedIdentifier<CommunityConfigDatabase>()
}

class CommunityConfigDatabase: InjectableObject {
    static let injectedIdentifier = Injected.communityConfigDatabase

    private let context: NSManagedObjectContext

    init(injector: Injector) {
        let coreDataStack = injector.getInjected(identifiedBy: Injected.configCoreDataStack)
        context = coreDataStack.saveContext
    }

    func configPublisher() -> AnyPublisher<CommunityConfig?, Error> {
        (context
            .publisher(request: CommunityConfigEntity.fetch()) {
                guard let configEntity = $0.first else { return [] }
                return [CommunityConfig(from: configEntity)]
            } as AnyPublisher<[CommunityConfig], Error>
        )
        .map(\.first)
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }

    func upsert(config: CommunityConfig) async throws {
        try await context.performAsync { [context] in
            let configEntity: CommunityConfigEntity
            if let existingConfig = try context.fetch(CommunityConfigEntity.fetch()).first {
                configEntity = existingConfig
            } else {
                configEntity = CommunityConfigEntity(context: context)
            }
            configEntity.fill(with: config, context: context)

            try context.save()
        }
    }
}
