//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import Combine
import os
import OctopusDependencyInjection

extension Injected {
    static let configCoreDataStack = Injector.InjectedIdentifier<ConfigCoreDataStack>()
}

class ConfigCoreDataStack: InjectableObject, @unchecked Sendable {
    static let injectedIdentifier = Injected.configCoreDataStack

    lazy var saveContext: NSManagedObjectContext = {
        stackManager.saveContext
    }()

    private static let persistentContainerName = "ConfigModel"
    private let stackManager: CoreDataStackManager

    init(inRam: Bool = false) throws(CoreDataErrors) {
        stackManager = try CoreDataStackManager(persistentContainerName: Self.persistentContainerName, inRam: inRam)
    }
}
