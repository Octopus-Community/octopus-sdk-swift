//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

enum CoreDataErrors: Error, CustomStringConvertible {
    case modelFileNotFound(String)
    case modelFileCorrupted(URL)

    var description: String {
        switch self {
        case let .modelFileNotFound(name):
            return "A model file named \(name) cannot be found in the module."
        case let .modelFileCorrupted(url):
            return "The model file located at \(url.relativePath) cannot be used to initialize the " +
                "NSManagedObjectModel"
        }
    }
}
