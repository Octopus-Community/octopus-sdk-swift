//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation

/// An object that can be injected inside the Injector
public protocol InjectableObject: AnyObject {
    associatedtype InjectableClass = Self
    
    /// Identifier of this injectable object. This is the identifier that needs to be used to get the injected object
    /// from the injector.
    static var injectedIdentifier: Injector.InjectedIdentifier<InjectableClass> { get }
}
