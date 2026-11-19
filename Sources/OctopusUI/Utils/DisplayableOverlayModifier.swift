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
    /// Builds the overlay from the window's safe area, which the overlay is centered on, so it can size to it.
    let overlayContent: (_ windowSafeArea: CGRect) -> OverlayContent

    @Environment(\.layoutDirection) private var layoutDirection

    @State private var buttonFrame: CGRect = .zero
    @State private var windowSafeArea: CGRect = .zero
    @State private var emojiBarWidth: CGFloat = .zero

    private let rectSize = CGSize(width: 3000, height: 3000)

    func body(content: Content) -> some View {
        content
            .readWindowSafeArea($windowSafeArea)
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
                    .accessibilityHidden(true)
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
                            .accessibilityHidden(true)
                            .overlay(
                                // Position the emoji bar above the button.
                                // `emojiBarXPosition` is computed in physical (LTR) coordinates
                                // from `windowSafeArea` and `buttonFrame.midX` (both physical),
                                // so we force LTR here — `.position` and `.topLeading` otherwise
                                // mirror their X axis under RTL, which breaks the placement.
                                // The inner `overlayContent` restores the caller's direction.
                                ZStack {
                                    overlayContent(windowSafeArea)
                                        .environment(\.layoutDirection, layoutDirection)
                                        .readWidth($emojiBarWidth)
                                        .position(
                                            x: emojiBarXPosition,
                                            y: rectSize.height / 2 - (buttonFrame.height + verticalPadding)
                                        )
                                        .transition(.scale.combined(with: .opacity))
                                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPresented)
                                        .accessibilityHidden(false)
                                },
                                alignment: .topLeading
                            )
                            .environment(\.layoutDirection, .leftToRight)
                    }
                }
            )
    }

    var emojiBarXPosition: CGFloat {
        overlayXPosition(centeredOn: windowSafeArea, anchorMidX: buttonFrame.midX, overlayRectWidth: rectSize.width)
    }
}

/// X position, in the overlay rect, of a view centered on the window's safe area: the rect is itself centered on the
/// anchor (the button), so the offset is the distance from the anchor to the center of the safe area. The safe area,
/// not the window, is the reference because it is not centered in the window when the camera sits on a side edge.
/// The rect's center is used while the safe area is unknown.
func overlayXPosition(centeredOn safeArea: CGRect, anchorMidX: CGFloat, overlayRectWidth: CGFloat) -> CGFloat {
    guard safeArea.width > 0 else { return overlayRectWidth / 2 }
    return overlayRectWidth / 2 + (safeArea.midX - anchorMidX)
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
        @ViewBuilder overlayContent: @escaping (_ windowSafeArea: CGRect) -> Content
    ) -> some View {
        self.modifier(DisplayableOverlayModifier(
            isPresented: isPresented,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            overlayContent: overlayContent))
    }
}
