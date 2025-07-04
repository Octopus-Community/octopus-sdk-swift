//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import SwiftUI

/// Information needed for a zoomable image
/// These info are used to display it and for the animation
struct ZoomableImageInfo: Equatable {
    let url: URL
    let image: Image
    /// Image that will be used during transition between Image and Zoomable image.
    /// Used when the image and the zoomed image do not have the same ratio
    let transitionImage: Image?

    init(url: URL, image: Image, transitionImage: Image? = nil) {
        self.url = url
        self.image = image
        self.transitionImage = transitionImage
    }
}


/// A view that displays an image that the user can zoom in and drag it.
/// Zoom and drag gestures ensure that the image is kept inside parent's bounds.
/// An identifier can be passed to be used in a matched geometry effet
struct ZoomableImageView: View {
    let image: Image
    let identifier: URL
    let isDisplayed: Bool

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    @State private var imageSize: CGSize = .zero
    @State private var containerSize: CGSize = .zero

    @State private var pinchCenterInView: CGPoint = .zero
    @State private var lastPinchCenter: CGPoint?

    // For velocity-based panning
    @State private var dragVelocity: CGSize = .zero
    @State private var isDecelerating: Bool = false
    @State private var decelerationTimer: Timer? = nil

    var body: some View {
        GeometryReader { containerGeo in
            ZStack {
                Color(UIColor.systemBackground)

                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .background(
                        GeometryReader { imageGeo in
                            Color.clear
                                .onAppear {
                                    imageSize = imageGeo.size
                                    containerSize = containerGeo.size
                                }
                                .onValueChanged(of: imageGeo.size) { newSize in
                                    imageSize = newSize
                                    containerSize = containerGeo.size
                                }
                        }
                    )
                    .scaleEffect(scale)
                    .offset(offset)
                    .namespacedMatchedGeometryEffect(id: identifier, isSource: false)
            }
            .frame(maxWidth: .infinity)
        }
        .modify {
            if #available(iOS 18.0, *) {
                $0.gesture(
                    SimultaneousGesture(
                        zoomGesture(),
                        dragGesture
                    )
                )
            } else {
                $0.gesture(
                    SimultaneousGesture(
                        zoomGestureOld,
                        dragGesture
                    )
                )
            }
        }
        .onValueChanged(of: isDisplayed) { isDisplayed in
            guard !isDisplayed else { return }
            withAnimation(.spring(duration: 0.05)) {
                scale = 1.0
                offset = .zero
            }
        }
        .onDisappear {
            stopDeceleration()
        }
    }

    private func clampedOffset(for proposedOffset: CGSize, scale: CGFloat) -> CGSize {
        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale

        let maxX = max((scaledWidth - containerSize.width) / 2, 0)
        let maxY = max((scaledHeight - containerSize.height) / 2, 0)

        let clampedX = min(max(proposedOffset.width, -maxX), maxX)
        let clampedY = min(max(proposedOffset.height, -maxY), maxY)

        return CGSize(width: clampedX, height: clampedY)
    }

    private var zoomGestureOld: some Gesture {
        SimultaneousGesture(
            // needed in order to track the initial touch point, in order to zoom relatively to that point
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    // sometimes, the onChanged is not called, this is why we use SpatialEventGesture when possible
                    pinchCenterInView = value.startLocation
                },
            magnificationGesture
        )
    }

    @available(iOS 18.0, *)
    private func zoomGesture() -> some Gesture {
        SimultaneousGesture(
            SpatialEventGesture(coordinateSpace: .local)
                .onChanged { events in
                    var locations: [CGPoint] = []
                    for event in events {
                        locations.append(event.location)
                    }
                    switch locations.count {
                    case 0, 1: break
                    default:
                        let currentCenter = CGPoint(
                            x: (locations[0].x + locations[1].x) / 2,
                            y: (locations[0].y + locations[1].y) / 2
                        )

                        if let lastCenter = lastPinchCenter {
                            let delta = CGSize(
                                width: currentCenter.x - lastCenter.x,
                                height: currentCenter.y - lastCenter.y
                            )
                            offset = clampedOffset(for: CGSize(
                                width: offset.width + delta.width,
                                height: offset.height + delta.height
                            ), scale: scale)
                        }

                        pinchCenterInView = currentCenter
                        lastPinchCenter = currentCenter
                    }
                }
                .onEnded { _ in
                    lastScale = scale
                    lastOffset = offset
                    lastPinchCenter = nil
                },
            magnificationGesture
        )
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                stopDeceleration()
                
                let newScale = max(1, lastScale * value)

                // Calculate the vector from pinch center to center of view
                let center = CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
                let vectorToCenter = CGSize(
                    width: pinchCenterInView.x - center.x,
                    height: pinchCenterInView.y - center.y
                )

                let deltaScale = newScale / scale

                // Adjust offset to simulate zoom around finger
                let newOffset = CGSize(
                    width: (offset.width - vectorToCenter.width) * deltaScale + vectorToCenter.width,
                    height: (offset.height - vectorToCenter.height) * deltaScale + vectorToCenter.height
                )

                scale = newScale
                offset = clampedOffset(for: newOffset, scale: scale)
            }
            .onEnded { _ in
                lastScale = scale
                lastOffset = offset
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                stopDeceleration()

                // Calculate drag velocity
                dragVelocity = value.velocity

                let proposedOffset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
                offset = clampedOffset(for: proposedOffset, scale: scale)
            }
            .onEnded { _ in
                lastOffset = offset

                // Apply inertia based on velocity
                if abs(dragVelocity.width) > 100 || abs(dragVelocity.height) > 100 {
                    startDeceleration()
                }
            }
    }

    private func startDeceleration() {
        isDecelerating = true

        var currentVelocity = dragVelocity
        let decelerationFactor: CGFloat = 0.95

        stopDeceleration()

        decelerationTimer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { timer in
            DispatchQueue.main.async {
                let velocityOffset = CGSize(
                    width: currentVelocity.width * 1/60,
                    height: currentVelocity.height * 1/60
                )

                let newOffset = CGSize(
                    width: offset.width + velocityOffset.width,
                    height: offset.height + velocityOffset.height
                )

                offset = clampedOffset(for: newOffset, scale: scale)
                lastOffset = offset

                currentVelocity.width *= decelerationFactor
                currentVelocity.height *= decelerationFactor

                if abs(currentVelocity.width) < 10 && abs(currentVelocity.height) < 10 {
                    stopDeceleration()
                }
            }
        }
    }

    private func stopDeceleration() {
        decelerationTimer?.invalidate()
        decelerationTimer = nil
        isDecelerating = false
    }
}
