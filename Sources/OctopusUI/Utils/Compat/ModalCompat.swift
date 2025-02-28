//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

extension View {
    @_disfavoredOverload
    nonisolated func fullScreenCover<Content>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content) -> some View where Content : View {
            if #available(iOS 14.0, *) {
                return fullScreenCover(isPresented: isPresented, onDismiss: onDismiss, content: content)
            } else {
                return sheet(isPresented: isPresented, onDismiss: onDismiss, content: content)
            }
        }
}
