//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
@preconcurrency import CoreData
import Combine
import os

extension NSManagedObjectContext {
    func publisher<Entity: NSManagedObject, MappedEntity>(
        request: NSFetchRequest<Entity>,
        relatedTypes: [NSManagedObject.Type] = [],
        transform: @escaping @Sendable ([Entity]) -> [MappedEntity])
    -> AnyPublisher<[MappedEntity], Never> {
            return publisher(observing: [Entity.self] + relatedTypes) { [weak self] in
                guard let self else { return [] }
                return transform(try self.fetch(request))
            }
        }

    /// Publisher variant that chunks IDs to avoid exceeding SQLite's variable limit.
    func chunkedPublisher<Entity: NSManagedObject, MappedEntity>(
        ids: [String],
        requestBuilder: @escaping @Sendable ([String]) -> NSFetchRequest<Entity>,
        relatedTypes: [NSManagedObject.Type] = [],
        transform: @escaping @Sendable ([Entity]) -> [MappedEntity])
    -> AnyPublisher<[MappedEntity], Never> {
            return publisher(observing: [Entity.self] + relatedTypes) { [weak self] in
                guard let self else { return [] }
                return transform(try self.chunkedFetch(ids: ids, requestBuilder: requestBuilder))
            }
        }

    /// Publishes the result of `fetch` right away, and again after every save of this context that
    /// inserts, updates or deletes one of `managedObjectTypes`.
    ///
    /// Two things about the shape below are load-bearing, and they pull in opposite directions:
    ///
    /// - The save observer is registered *before* the first fetch reads the store. The obvious spelling,
    ///   `notifications.prepend(())`, gets that backwards: Combine subscribes a prepended publisher's
    ///   upstream only once the prepended element has finished being delivered, and that delivery is
    ///   where the fetch used to run. A save committed in between was observed by nobody, so the
    ///   publisher then sat forever on whatever that first fetch happened to read. On a loaded machine,
    ///   where the thread wiring up the subscription is easily descheduled mid-window, the lost update
    ///   surfaced as subscribers waiting endlessly for a change that had already been written.
    /// - The first fetch runs here, in the subscription's own setup, rather than as the first element of
    ///   a Combine chain. It blocks on this context's queue, and `NSManagedObjectContextDidSave` is
    ///   posted from inside `save()` — by the thread that owns that queue. Running it while holding a
    ///   lock that thread needs to publish its own save deadlocks the two, which rules out every
    ///   element-combining operator (`merge`, `flatMap`, feeding a subject…): they all serialise
    ///   deliveries behind exactly such a lock. Hence a plain precomputed value, concatenated in front.
    ///
    /// Save-driven fetches still run inline on the thread that saved, and subscribers are still called
    /// there, so nothing about when or where updates arrive changes.
    ///
    /// A fetch that throws is logged and skipped, never published as a failure: the subscription stays
    /// alive and the next save retries it. Failing would be worse than useless here — the failures that
    /// happen are transient (tearing a stack down pulls the persistent stores out from under contexts
    /// that are still subscribed), while a completion is forever, leaving the subscriber deaf to every
    /// later save with nothing but a nil or an empty array to show for it. Nobody up the chain ever had
    /// anything to do with such an error either, hence `Failure == Never` rather than an error no caller
    /// can act on.
    func publisher<MappedEntity>(
        observing managedObjectTypes: [NSManagedObject.Type],
        fetch: @escaping @Sendable () throws -> [MappedEntity])
    -> AnyPublisher<[MappedEntity], Never> {
        Deferred { [weak self] () -> AnyPublisher<[MappedEntity], Never> in
            guard let self else { return Empty<[MappedEntity], Never>().eraseToAnyPublisher() }

            // Keeps the latest save-driven fetch, so a save landing before the subscriber below is
            // attached — the window the first bullet above describes — is replayed rather than dropped.
            let saved = CurrentValueSubject<[MappedEntity]?, Never>(nil)
            let observation = NotificationCenter.default
                .publisher(for: .NSManagedObjectContextDidSave, object: self)
                .filter { $0.isUpdateOf(managedObjectTypes: managedObjectTypes) }
                .sink { [weak self] _ in
                    guard let self else { return }
                    do {
                        saved.send(try self.performAndWaitIfAvailable(fetch))
                    } catch {
                        if #available(iOS 14, *) {
                            Logger.other.debug("Fetch after a save failed, skipping this update: \(error)")
                        }
                    }
                }

            // A nil initial value publishes nothing rather than ending the stream: the observer above is
            // already registered, so the next save fetches again.
            let initialValue: [MappedEntity]?
            do {
                initialValue = try self.performAndWaitIfAvailable(fetch)
            } catch {
                if #available(iOS 14, *) {
                    Logger.other.debug("First fetch failed, publishing nothing until the next save: \(error)")
                }
                initialValue = nil
            }

            return saved
                .prepend(initialValue)
                .compactMap { $0 }
                .handleEvents(receiveCompletion: { _ in observation.cancel() },
                              receiveCancel: { observation.cancel() })
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

    /// Runs `block` on this context's queue where the API to do so synchronously exists.
    private func performAndWaitIfAvailable<T>(_ block: @Sendable () throws -> T) throws -> T {
        if #available(iOS 15.0, *) {
            return try performAndWait(block)
        } else {
            return try block()
        }
    }
}

/// Add CoreData conditional behavior to Notification
extension Notification {

    /// Check if notification is an insert/update/delete
    /// of the given NSManagedObject type or one of its related types (needed for relationships)
    ///
    /// - Parameter managedObjectTypes: The list of managed object classes that matters
    func isUpdateOf<T: NSManagedObject>(managedObjectTypes: [T.Type]) -> Bool {
        let inserted = userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
        let updated = userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []
        let deleted = userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? []
        let allChanges = inserted.union(updated).union(deleted)
        return allChanges.contains { typeChanged in
            managedObjectTypes.contains { typeChanged.isKind(of: $0) }
        }
    }
}
