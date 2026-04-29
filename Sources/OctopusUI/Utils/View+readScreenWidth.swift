//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

/// Reads the window width from the UIKit view hierarchy.
private struct WindowWidthReader: UIViewRepresentable {
    @Binding var width: CGFloat

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isHidden = true
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            if let window = uiView.window {
                let newWidth = window.bounds.width
                if newWidth != width {
                    width = newWidth
                }
            }
        }
    }
}

extension View {
    func readScreenWidth(_ width: Binding<CGFloat>) -> some View {
        background(WindowWidthReader(width: width))
    }
}
