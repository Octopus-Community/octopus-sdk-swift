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

private struct DebugPrintHeightModifier: ViewModifier {
    let identifier: String
    @State private var height: CGFloat = 0

    private var sizeView: some View {
        GeometryReader { geometry in
            Color.clear
                .onValueChanged(of: geometry.size.height, initial: true) {
                    height = $0
                    print("height of \(identifier): \($0)")
                }

        }
    }

    func body(content: Content) -> some View {
        content
            .background(sizeView)
            .overlay(
                Color.gray.opacity(0.5)
                    .background(
                        Text(verbatim: "\(Int(height))")
                    )
            )
    }
}

private struct DebugPrintWidthModifier: ViewModifier {
    let identifier: String
    @State private var width: CGFloat = 0

    private var sizeView: some View {
        GeometryReader { geometry in
            Color.clear
                .onValueChanged(of: geometry.size.width, initial: true) {
                    width = $0
                    print("width of \(identifier): \($0)")
                }

        }
    }

    func body(content: Content) -> some View {
        content
            .background(sizeView)
            .overlay(
                Color.gray.opacity(0.5)
                    .background(
                        Text(verbatim: "\(Int(width))")
                    )
            )
    }
}

private struct DebugSizeForAccessibilityModifier: ViewModifier {
    @State private var size: CGSize = .zero

    private var sizeView: some View {
        GeometryReader { geometry in
            Color.clear
                .onValueChanged(of: geometry.size, initial: true) {
                    size = $0
                }

        }
    }

    func body(content: Content) -> some View {
        content
            .background(sizeView)
            .modify {
                if size.width < 44 || size.height < 44 {
                    $0.overlay(
                        Color.gray.opacity(0.5)
                            .background(
                                Text(verbatim: "\(Int(min(size.width, size.height)))")
                            )
                            .allowsHitTesting(false)
                    )
                } else { $0 }
            }

    }
}

extension View {
    func printHeight(identifier: String = "") -> some View {
        self.modifier(DebugPrintHeightModifier(identifier: identifier))
    }
}

extension View {
    func printWidth(identifier: String = "") -> some View {
        self.modifier(DebugPrintWidthModifier(identifier: identifier))
    }
}

extension View {
    func debugSizeForAccessibility() -> some View {
        self.modifier(DebugSizeForAccessibilityModifier())
    }
}
