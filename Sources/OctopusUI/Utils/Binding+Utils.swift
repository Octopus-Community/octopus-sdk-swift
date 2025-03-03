//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

extension Binding where Value: Equatable {
    @MainActor
    func validate(_ validationBlock: @escaping (Value) -> Value) -> Self {
        DispatchQueue.main.async {
            let validatedValue = validationBlock(wrappedValue)
            guard validatedValue != wrappedValue else { return }
            wrappedValue = validatedValue
        }
        return self
    }
}
