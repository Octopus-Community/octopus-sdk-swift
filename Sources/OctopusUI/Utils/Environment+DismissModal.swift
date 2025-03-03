//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct ModalDismissKey: EnvironmentKey {
    static let defaultValue = Binding<Bool>.constant(false) // < required
}

// define modalMode value
extension EnvironmentValues {
    var dismissModal: Binding<Bool> {
        get {
            return self[ModalDismissKey.self]
        }
        set {
            self[ModalDismissKey.self] = newValue
        }
    }
}
