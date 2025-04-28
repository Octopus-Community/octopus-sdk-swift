//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import Combine
import os
import OctopusDependencyInjection

extension Injected {
    static let modelCoreDataStack = Injector.InjectedIdentifier<ModelCoreDataStack>()
}

class ModelCoreDataStack: InjectableObject, @unchecked Sendable {
    static let injectedIdentifier = Injected.modelCoreDataStack

    lazy var saveContext: NSManagedObjectContext = {
        stackManager.saveContext
    }()

    private static let persistentContainerName = "OctopusModel"
    private let stackManager: CoreDataStackManager

    init(inRam: Bool = false) throws(CoreDataErrors) {
        stackManager = try CoreDataStackManager(persistentContainerName: Self.persistentContainerName, inRam: inRam)
    }
}
