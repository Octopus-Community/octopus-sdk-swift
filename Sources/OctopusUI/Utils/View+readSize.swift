//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

private struct ReadHeightModifier: ViewModifier {
    @Binding var height: CGFloat

    private var sizeView: some View {
        GeometryReader { geometry in
            Color.clear
                .onAppear {
                    $height.wrappedValue = geometry.size.height
                }
                .onValueChanged(of: geometry.size.height) {
                    $height.wrappedValue = $0
                }
        }
    }

    func body(content: Content) -> some View {
        content.background(sizeView)
    }
}

extension View {
    func readHeight(_ height: Binding<CGFloat>) -> some View {
        self.modifier(ReadHeightModifier(height: height))
    }
}

private struct ReadWidthModifier: ViewModifier {
    @Binding var width: CGFloat

    private var sizeView: some View {
        GeometryReader { geometry in
            Color.clear
                .onAppear {
                    $width.wrappedValue = geometry.size.width
                }
                .onValueChanged(of: geometry.size.width) {
                    $width.wrappedValue = $0
                }
        }
    }

    func body(content: Content) -> some View {
        content.background(sizeView)
    }
}

extension View {
    func readWidth(_ width: Binding<CGFloat>) -> some View {
        self.modifier(ReadWidthModifier(width: width))
    }
}
