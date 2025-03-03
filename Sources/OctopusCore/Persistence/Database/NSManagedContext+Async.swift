//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

extension NSManagedObjectContext {
    func performAsync<T>(_ block: @escaping () throws -> T) async throws -> T {
        if #available(iOS 15.0, *) {
            return try await perform(block)
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                perform {
                    do {
                        let result = try block()
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
}
