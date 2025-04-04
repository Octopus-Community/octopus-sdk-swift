//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import SwiftUI

extension View {
    /// A backwards compatible wrapper for iOS 14 `onChange`
    @ViewBuilder func onValueChanged<T: Equatable>(of value: T, onChange: @escaping (T) -> Void) -> some View {
        if #available(iOS 14.0, *) {
            self.onChange(of: value, perform: onChange)
        } else {
            self.onReceive(Just(value)) { (value) in
                onChange(value)
            }
        }
    }
}
