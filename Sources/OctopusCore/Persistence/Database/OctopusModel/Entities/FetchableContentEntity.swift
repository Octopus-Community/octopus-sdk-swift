//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import CoreData

protocol FetchableContentEntity: AnyObject {
    associatedtype Entity: OctoObjectEntity
    static func fetchAll() -> NSFetchRequest<Entity>
    static func fetchById(id: String) -> NSFetchRequest<Entity>
    static func fetchAllExcept(ids: [String]) -> NSFetchRequest<Entity>
    static func fetchAllByIds(ids: [String]) -> NSFetchRequest<Entity>
}
