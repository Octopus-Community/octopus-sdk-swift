//
//  Copyright © 2025 Octopus Community. All rights reserved.
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

    @_disfavoredOverload
    func fullScreenCover<Item, Content>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content) -> some View where Item : Identifiable, Content : View {
            if #available(iOS 14.0, *) {
                return fullScreenCover(item: item, onDismiss: onDismiss, content: content)
            } else {
                return sheet(item: item, onDismiss: onDismiss, content: content)
            }
        }
}

