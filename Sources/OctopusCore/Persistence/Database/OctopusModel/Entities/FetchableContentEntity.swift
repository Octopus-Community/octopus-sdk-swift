//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

protocol FetchableContentEntity: AnyObject {
    associatedtype Entity: OctoObjectEntity
    static func fetchAll() -> NSFetchRequest<Entity>
    static func fetchById(id: String) -> NSFetchRequest<Entity>
    static func fetchAllByIds(ids: [String]) -> NSFetchRequest<Entity>
    /// Additional predicate applied when selecting entities eligible for bulk deletion.
    /// Defaults to `nil` (all entities are eligible).
    static var additionalDeletionPredicate: NSPredicate? { get }
}

extension FetchableContentEntity {
    static var additionalDeletionPredicate: NSPredicate? { nil }
}
