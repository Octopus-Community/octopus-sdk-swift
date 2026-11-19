//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import UIKit

extension View {
    /// Lets the member pinch this view where it is: it grows under the fingers above the screen, then springs back
    /// into place when they lift. One-finger gestures and taps are left to the view and the scroll views around it.
    ///
    /// - Parameters:
    ///   - isEnabled: whether a new pinch may start.
    ///   - cornerRadius: the radius of the corners of the view at rest.
    ///   - roundedCorners: the corners rounded by `cornerRadius`.
    ///   - content: makes the copy drawn while zoomed, which fills the frame of this view; `nil` while there is
    ///     nothing to show yet.
    func inPlacePinchZoom(isEnabled: Bool = true, cornerRadius: CGFloat = 0,
                          roundedCorners: CACornerMask = .allCorners,
                          content: @escaping @MainActor () -> UIView?) -> some View {
        modifier(InPlacePinchZoomModifier(
            isEnabled: isEnabled, cornerRadius: cornerRadius, roundedCorners: roundedCorners, makeContent: content))
    }

    /// Lets the member pinch this photo where it is. The photo fills the frame of this view, cropped like
    /// `scaledToFill`, which is how a photo that fits its frame or fills it is drawn.
    func inPlacePinchZoom(image: UIImage, cornerRadius: CGFloat = 0,
                          roundedCorners: CACornerMask = .allCorners) -> some View {
        inPlacePinchZoom(cornerRadius: cornerRadius, roundedCorners: roundedCorners) {
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFill
            return imageView
        }
    }
}

private struct InPlacePinchZoomModifier: ViewModifier {
    let isEnabled: Bool
    let cornerRadius: CGFloat
    let roundedCorners: CACornerMask
    let makeContent: @MainActor () -> UIView?

    /// While zoomed, the copy above the screen stands for the view, which is hidden.
    @State private var isZooming = false

    func body(content: Content) -> some View {
        content
            .opacity(isZooming ? 0 : 1)
            .background(
                InPlacePinchZoomAnchor(
                    isEnabled: isEnabled, isZooming: isZooming, cornerRadius: cornerRadius,
                    roundedCorners: roundedCorners, makeContent: makeContent,
                    onZoomingChanged: { isZooming = $0 }))
    }
}

private struct InPlacePinchZoomAnchor: UIViewRepresentable {
    let isEnabled: Bool
    /// Whether the view is hidden for its copy. Read in the update that shows it again, so that the copy leaves the
    /// screen in the same frame as the view comes back.
    let isZooming: Bool
    let cornerRadius: CGFloat
    let roundedCorners: CACornerMask
    let makeContent: @MainActor () -> UIView?
    let onZoomingChanged: @MainActor (Bool) -> Void

    func makeUIView(context: Context) -> InPlacePinchZoomView {
        InPlacePinchZoomView()
    }

    func updateUIView(_ view: InPlacePinchZoomView, context: Context) {
        view.cornerRadius = cornerRadius
        view.roundedCorners = roundedCorners
        view.makeContent = makeContent
        view.onZoomingChanged = onZoomingChanged
        view.isZoomEnabled = isEnabled
        if !isZooming {
            view.photoIsShown()
        }
    }

    static func dismantleUIView(_ view: InPlacePinchZoomView, coordinator: ()) {
        view.endZoom(removingOverlayAtOnce: true)
        view.photoIsShown()
    }
}
