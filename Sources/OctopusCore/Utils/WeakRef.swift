//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation

final class WeakRef<T: AnyObject> {
    weak var value: T?

    init(_ value: T) {
        self.value = value
    }
}
