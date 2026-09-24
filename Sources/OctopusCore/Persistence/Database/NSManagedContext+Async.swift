//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

extension NSManagedObjectContext {
    /// Box for a closure whose captures Swift cannot prove `Sendable`.
    ///
    /// `perform` wants a `@Sendable` block, but `performAsync`'s callers are generic over their entity type
    /// and capture that generic's metatype, which cannot be constrained under swift-tools-version 6.0
    /// (`SendableMetatype` only exists from Swift 6.2, and raising the tools version would drop support for
    /// host apps on older Xcodes). The hop is safe here: the block is run exactly once, on the context's own
    /// queue, and is not touched anywhere else — so the unsafety is kept confined to this one place rather
    /// than spread over every caller.
    private struct UncheckedSendableBlock<T>: @unchecked Sendable {
        let run: () throws -> T
    }

    func performAsync<T>(_ block: @escaping () throws -> T) async throws -> T {
        // Ensure stores are loaded before making a query
        try await TaskUtils.wait(for: persistentStoreCoordinator?.persistentStores.isEmpty == false, timeout: 0.1)

        let block = UncheckedSendableBlock(run: block)
        if #available(iOS 15.0, *) {
            return try await perform { try block.run() }
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                perform {
                    do {
                        let result = try block.run()
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
}
