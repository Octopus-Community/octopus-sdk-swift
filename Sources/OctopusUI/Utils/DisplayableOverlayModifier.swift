//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

// MARK: - Modifier

struct DisplayableOverlayModifier<OverlayContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let overlayContent: () -> OverlayContent

    @State private var buttonFrame: CGRect = .zero
    @State private var emojiBarWidth: CGFloat = .zero

    private let rectSize = CGSize(width: 3000, height: 3000)

    func body(content: Content) -> some View {
        content
            .modify {
                if isPresented {
                    $0.background(
                        GeometryReader { proxy in
                            Color.clear
                            .onAppear {
                                buttonFrame = proxy.frame(in: .global)
                            }
                            .onValueChanged(of: proxy.frame(in: .global)) {
                                buttonFrame = $0
                            }
                        }
                    )
                } else {
                    $0
                }
            }
            .overlay(
                Group {
                    if isPresented {
                        // Large tap-interceptor rectangle
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: rectSize.width, height: rectSize.height) // Very large frame
                            .contentShape(Rectangle())
                            .onTapGesture {
                                    isPresented = false
                            }
                            .simultaneousGesture(DragGesture().onChanged { _ in
                                    isPresented = false
                            })
                            .overlay(
                                // Position the emoji bar above the button
                                ZStack {
                                    overlayContent()
                                        .readWidth($emojiBarWidth)
                                        .position(
                                            x: emojiBarXPosition, //buttonFrame.midX,
                                            y: rectSize.height / 2 - (buttonFrame.height + verticalPadding)
                                        )
                                        .transition(.scale.combined(with: .opacity))
                                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPresented)
                                },
                                alignment: .topLeading
                            )
                    }
                }
            )
    }


    var emojiBarXPosition: CGFloat {
        let baseX = rectSize.width / 2

        if buttonFrame.minX + buttonFrame.width / 2 - emojiBarWidth / 2 < horizontalPadding {
            return baseX - (buttonFrame.minX + buttonFrame.width / 2 - emojiBarWidth / 2 - horizontalPadding)
        }
        return baseX
    }
}

private struct ContentGlobalFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

extension View {
    func displayableOverlay<Content: View>(
        isPresented: Binding<Bool>,
        horizontalPadding: CGFloat,
        verticalPadding: CGFloat,
        @ViewBuilder overlayContent: @escaping () -> Content
    ) -> some View {
        self.modifier(DisplayableOverlayModifier(
            isPresented: isPresented,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            overlayContent: overlayContent))
    }
}
