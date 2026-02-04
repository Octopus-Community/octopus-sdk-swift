//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import Combine
import OctopusDependencyInjection

extension Injected {
    static let eventsDatabase = Injector.InjectedIdentifier<EventsDatabase>()
}

class EventsDatabase: InjectableObject {
    static let injectedIdentifier = Injected.eventsDatabase

    private let context: NSManagedObjectContext

    init(injector: Injector) {
        let coreDataStack = injector.getInjected(identifiedBy: Injected.trackingCoreDataStack)
        context = coreDataStack.saveContext
    }

    func eventsPublisher() -> AnyPublisher<[Event], Error> {
        return context
            .publisher(request: EventEntity.fetchAll()) {
                $0.compactMap { Event(from: $0) }
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func upsert(events: [Event]) async throws {
        try await context.performAsync { [context] in
            for event in events {
                EventEntity.create(from: event, context: context)
            }
            try context.save()
        }
    }

    func upsert(event: Event) async throws {
        try await context.performAsync { [context] in
            EventEntity.create(from: event, context: context)
            try context.save()
        }
    }

    func incrementSendingAttempts(ids: [String]) async throws {
        try await context.performAsync { [context] in
            let request = EventEntity.fetchAllByIds(ids: ids)
            let existingEvents = try context.fetch(request)

            for event in existingEvents {
                event.sendingAttempts += 1
            }
            try context.save()
        }
    }

    func deleteAll(ids: [String]) async throws {
        try await context.performAsync { [context] in
            let request = EventEntity.fetchAllByIds(ids: ids)
            let existingEvents = try context.fetch(request)

            for event in existingEvents {
                context.delete(event)
            }
            try context.save()
        }
    }
}
