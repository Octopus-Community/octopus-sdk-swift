//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

/// SQLite has a compile-time limit on the number of bind variables per statement
/// (`SQLITE_MAX_VARIABLE_NUMBER`, typically 999). CoreData's `IN %@` predicates
/// generate one variable per element, so large arrays can exceed this limit.
/// These helpers chunk the work into multiple queries to stay within the limit.
private let sqliteVariableLimit = 500

extension NSManagedObjectContext {

    /// Fetches entities in chunks to avoid exceeding SQLite's variable limit.
    ///
    /// - Parameters:
    ///   - ids: The full list of identifiers to query.
    ///   - requestBuilder: A closure that builds a fetch request for a chunk of IDs.
    /// - Returns: The merged results from all chunk fetches.
    func chunkedFetch<T: NSManagedObject>(
        ids: [String],
        requestBuilder: ([String]) -> NSFetchRequest<T>
    ) throws -> [T] {
        guard !ids.isEmpty else { return [] }
        guard ids.count > sqliteVariableLimit else {
            return try fetch(requestBuilder(ids))
        }
        var results = [T]()
        for chunk in ids.chunked(into: sqliteVariableLimit) {
            results.append(contentsOf: try fetch(requestBuilder(chunk)))
        }
        return results
    }

    /// Batch-deletes entities in chunks to avoid exceeding SQLite's variable limit.
    ///
    /// - Parameters:
    ///   - ids: The full list of identifiers to delete.
    ///   - requestBuilder: A closure that builds a fetch request (as `NSFetchRequestResult`) for a chunk of IDs.
    func chunkedBatchDelete(
        ids: [String],
        requestBuilder: ([String]) -> NSFetchRequest<NSFetchRequestResult>
    ) throws {
        guard !ids.isEmpty else { return }
        for chunk in ids.chunked(into: sqliteVariableLimit) {
            let request = requestBuilder(chunk)
            request.includesPropertyValues = false
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            try execute(batchDeleteRequest)
        }
    }
}
