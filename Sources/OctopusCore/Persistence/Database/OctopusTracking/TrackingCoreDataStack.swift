//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import Combine
import os
import OctopusDependencyInjection

extension Injected {
    static let trackingCoreDataStack = Injector.InjectedIdentifier<TrackingCoreDataStack>()
}

/// CoreData stack of the `OctopusTracking` model.
class TrackingCoreDataStack: InjectableObject, @unchecked Sendable {
    static let injectedIdentifier = Injected.trackingCoreDataStack

    lazy var saveContext: NSManagedObjectContext = {
        stackManager.saveContext
    }()

    private static let persistentContainerName = "OctopusTracking"
    private let stackManager: CoreDataStackManager

    init(inRam: Bool = false) throws(CoreDataErrors) {
        stackManager = try CoreDataStackManager(persistentContainerName: Self.persistentContainerName, inRam: inRam)
    }
}
