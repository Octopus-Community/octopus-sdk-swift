//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import CoreGraphics

/// Where a photo zoomed in place is drawn: a scale around its top-left corner, then a translation of that corner.
///
/// The points are in the coordinates of the photo at rest: `(0, 0)` is its top-left corner, before any zoom.
struct InPlacePinchZoomTransform: Equatable {
    /// The largest scale: past it, the photo stops growing while the fingers keep spreading.
    static let maxScale: CGFloat = 4
    /// The opacity of the black backdrop at the largest scale.
    static let maxDimAlpha: CGFloat = 0.6

    private(set) var scale: CGFloat = 1
    /// The translation of the top-left corner of the photo.
    private(set) var offset: CGPoint = .zero

    init() { }

    /// The transform that draws the photo laid out in `source` at `frame`. The scale comes from the widths, which
    /// keep the ratio of the photo.
    init(frame: CGRect, source: CGRect) {
        guard source.width > 0 else { return }
        scale = min(max(frame.width / source.width, 1), Self.maxScale)
        offset = CGPoint(x: frame.minX - source.minX, y: frame.minY - source.minY)
    }

    /// The opacity of the backdrop: none at rest, growing with the scale up to `maxDimAlpha`.
    var dimAlpha: CGFloat {
        min(max((scale - 1) / (Self.maxScale - 1), 0), 1) * Self.maxDimAlpha
    }

    /// Whether the photo is drawn where it is laid out.
    var isIdentity: Bool { scale == 1 && offset == .zero }

    /// Follows the fingers: the point of the photo that was under `previousCentroid` goes under `centroid`, and
    /// the photo grows by `zoom`.
    ///
    /// The ratio applied to the offset is the one of the clamped scale: at a limit, the photo only follows the
    /// fingers, it never jumps.
    mutating func apply(zoom: CGFloat, from previousCentroid: CGPoint, to centroid: CGPoint) {
        guard zoom.isFinite, zoom > 0 else { return }
        let nextScale = min(max(scale * zoom, 1), Self.maxScale)
        let ratio = nextScale / scale
        offset = CGPoint(
            x: centroid.x - (previousCentroid.x - offset.x) * ratio,
            y: centroid.y - (previousCentroid.y - offset.y) * ratio)
        scale = nextScale
    }

    /// Where the photo laid out in `source` is drawn.
    func frame(for source: CGRect) -> CGRect {
        CGRect(
            x: source.minX + offset.x,
            y: source.minY + offset.y,
            width: source.width * scale,
            height: source.height * scale)
    }
}
