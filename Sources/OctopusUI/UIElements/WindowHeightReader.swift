//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import UIKit

/// Reports the height of the window that hosts the view it is attached to.
///
/// `UIScreen.main` is the main screen's size, not the size of the window the SDK is shown in: it is wrong on a
/// second screen or in an iPad window shorter than the screen (Stage Manager, windowed apps), and it is deprecated
/// since iOS 16. The height is `0` while the view is not in a window yet; it follows the window when it is rotated or
/// resized.
private struct WindowHeightReader: UIViewRepresentable {
    @Binding var height: CGFloat

    func makeUIView(context: Context) -> WindowMetricView<CGFloat> {
        let view = WindowMetricView<CGFloat> { $0?.bounds.height ?? 0 }
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        view.onChange = publish
        return view
    }

    func updateUIView(_ uiView: WindowMetricView<CGFloat>, context: Context) {
        uiView.onChange = publish
    }

    private func publish(_ newHeight: CGFloat) {
        // Writing an unchanged value would still invalidate the views that read the binding.
        if height != newHeight {
            height = newHeight
        }
    }
}

extension View {
    /// Writes the height of the window hosting this view into `height` (`0` while it is unknown), and keeps it up
    /// to date when the window is rotated or resized.
    func readWindowHeight(_ height: Binding<CGFloat>) -> some View {
        background(
            WindowHeightReader(height: height)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        )
    }
}

/// The window height to size against: the measured one, or the screen's while the window is not known yet.
///
/// The window height reaches the views one main-actor turn after the first layout pass, and a view that applied no
/// cap during that pass would size itself uncapped (an oversized sheet detent, a notice at its full height) before
/// the window is known. The screen's height is the best guess available then, and only then: it is the main screen's
/// size, wrong in a resized iPad window or on a second screen, so it is never used once the window has reported.
func resolvedWindowHeight(measured: CGFloat, fallback: CGFloat) -> CGFloat {
    measured > 0 ? measured : fallback
}

/// Height of the main screen, the provisional window height while the real one is unknown (see
/// ``resolvedWindowHeight(measured:fallback:)``).
@MainActor
var provisionalWindowHeight: CGFloat { UIScreen.main.bounds.height }
