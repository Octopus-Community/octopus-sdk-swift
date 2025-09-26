//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
@preconcurrency import CoreData
import Combine

extension NSManagedObjectContext {
    func publisher<Entity: NSManagedObject, MappedEntity>(
        request: NSFetchRequest<Entity>,
        transform: @escaping @Sendable ([Entity]) -> [MappedEntity])
    -> AnyPublisher<[MappedEntity], Error> {
            return NotificationCenter.default
                .publisher(for: .NSManagedObjectContextDidSave, object: self)
                .filter { $0.isUpdateOf(managedObjectType: Entity.self) }
                .map { _ in return Void() }
                .prepend(Void())
                .tryMap { [weak self] in
                    guard let self else { return [] }
                    if #available(iOS 15.0, *) {
                        return try self.performAndWait {
                            transform(try self.fetch(request))
                        }
                    } else {
                        return transform(try self.fetch(request))
                    }
                }
                .eraseToAnyPublisher()
        }
}

/// Add CoreData conditional behavior to Notification
extension Notification {

    /// Check if notification is an insert/update/delete
    /// of the given NSManagedObject type
    ///
    /// - Parameter managedObjectType: The managed object class
    func isUpdateOf<T: NSManagedObject>(managedObjectType: T.Type) -> Bool {
        let inserted = userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
        let updated = userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []
        let deleted = userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? []
        return inserted.union(updated).union(deleted).contains(where: { $0 is T })
    }
}

