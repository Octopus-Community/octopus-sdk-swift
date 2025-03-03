//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine

/// The injector and container of all injected objects.
public final class Injector {
    /// Identifier of an injectable object
    public final class InjectedIdentifier<Injected>: Sendable {
        fileprivate let uuid = UUID()

        /// Constructor
        public init() { }
    }

    /// State in which an injected object can be.
    private enum InjectedObjectState {
        /// The object is injected but not initialized yet.
        case factory((Injector) -> AnyObject)
        /// The injected object is initialized
        case initialized(AnyObject)
    }

    /// Dictionary of injected objects, indexed by the UUID of their `InjectedIdentifier`.
    private var injectedObjects = [UUID: InjectedObjectState]()

    /// Constructor
    public init() { }

    /// Inject an injectable object.
    /// - Parameter factory: a block to construct (when needed) the object
    /// - Note: Injecting an object that has the same identifier as an object that is already in the injector will fail
    public func register<IO: InjectableObject>(factory: @escaping (_ container: Injector) -> IO) {
        guard injectedObjects[IO.injectedIdentifier.uuid] == nil else {
            preconditionFailure("Injectable object already registered")
        }
        injectedObjects[IO.injectedIdentifier.uuid] = .factory(factory)
    }
    
    /// Gets an injected object using its identifier
    /// - Parameter identifier: the identifier of the object
    /// - Returns: the injected object
    public func getInjected<IO>(identifiedBy identifier: InjectedIdentifier<IO>) -> IO {
        guard let injectedObjectState = injectedObjects[identifier.uuid] else {
            // Implementation error, it is ok to crash as it is a developper error
            fatalError("Injectable object \(identifier) not found")
        }
        switch injectedObjectState {
        case .initialized(let service):
            return service as! IO
        case .factory(let factory):
            let injectedObject = factory(self) as! IO
            injectedObjects[identifier.uuid] = .initialized(injectedObject as AnyObject)
            return injectedObject
        }
    }
}
