//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import UIKit

/// Reports the safe area of the window that hosts the view it is attached to, in the window's coordinates.
///
/// The safe area is not always centered in the window: on a device whose camera sits on a side edge, the inset is
/// on that edge only, so an overlay centered on the window would be off-center and run under the camera.
private struct WindowSafeAreaReader: UIViewRepresentable {
    @Binding var safeArea: CGRect

    func makeUIView(context: Context) -> WindowMetricView<CGRect> {
        let view = WindowMetricView<CGRect> { window in
            guard let window else { return .zero }
            return windowSafeArea(bounds: window.bounds, insets: window.safeAreaInsets)
        }
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        view.onChange = publish
        return view
    }

    func updateUIView(_ uiView: WindowMetricView<CGRect>, context: Context) {
        uiView.onChange = publish
    }

    private func publish(_ newSafeArea: CGRect) {
        // Writing an unchanged value would still invalidate the views that read the binding.
        if safeArea != newSafeArea {
            safeArea = newSafeArea
        }
    }
}

/// The part of a window's bounds that its safe area insets leave free.
func windowSafeArea(bounds: CGRect, insets: UIEdgeInsets) -> CGRect {
    bounds.inset(by: insets)
}

extension View {
    /// Writes the safe area of the window hosting this view into `safeArea`, in the window's coordinates (`.zero`
    /// while it is unknown), and keeps it up to date when the window is rotated or resized.
    func readWindowSafeArea(_ safeArea: Binding<CGRect>) -> some View {
        background(
            WindowSafeAreaReader(safeArea: safeArea)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        )
    }
}
