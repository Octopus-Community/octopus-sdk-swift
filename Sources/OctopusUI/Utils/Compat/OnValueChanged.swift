//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import SwiftUI

extension View {
    /// A backwards compatible wrapper for iOS 14 `onChange`
    @ViewBuilder func onValueChanged<T: Equatable>(of value: T, initial: Bool = false, onChange: @escaping (T) -> Void) -> some View {
        if #available(iOS 17.0, *) {
            self.onChange(of: value, initial: initial) { _, newValue in
                onChange(newValue)
            }
        } else if #available(iOS 14.0, *) {
            self
                .onChange(of: value, perform: onChange)
                .modify {
                    if initial {
                        $0.onAppear {
                            onChange(value)
                        }
                    } else {
                        $0
                    }
                }
        } else {
            self.onReceive(Just(value)) { (value) in
                onChange(value)
            }
        }
    }
}
