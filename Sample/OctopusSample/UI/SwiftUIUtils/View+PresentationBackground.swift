//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

extension View {
    /// Apply a safe area inset to this view.
    /// When the keyboard is displayed, remove the inset
    /// - Parameter bottomSafeAreaInset: the bottom safe area to set
    @_disfavoredOverload
    func presentationBackground(_ color: Color) -> some View {
        self
            .modify {
                if #available(iOS 16.4, *) {
                    $0.presentationBackground(color)
                } else {
                    $0
                }
            }
    }
}
