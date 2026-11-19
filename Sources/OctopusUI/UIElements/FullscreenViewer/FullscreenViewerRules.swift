//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import CoreGraphics

/// The zoom rules of a photo in the fullscreen viewer. Scales are the factor applied to the photo's pixel size.
enum ZoomRules {
    /// How far the photo can be zoomed, as a multiple of the fit scale.
    private static let maxScaleFactor: CGFloat = 5
    /// How far a double tap zooms a photo that already fills the screen, as a multiple of the fit scale.
    private static let sameRatioDoubleTapFactor: CGFloat = 2.5
    /// A scale this close to the fit scale still counts as not zoomed.
    private static let zoomedTolerance: CGFloat = 1.01

    /// The scale at which the whole photo is shown. It is also the minimum zoom.
    static func fitScale(imageSize: CGSize, bounds: CGSize) -> CGFloat {
        guard imageSize.width > 0, imageSize.height > 0 else { return 1 }
        return min(bounds.width / imageSize.width, bounds.height / imageSize.height)
    }

    /// The scale at which the photo covers the whole bounds.
    static func fillScale(imageSize: CGSize, bounds: CGSize) -> CGFloat {
        guard imageSize.width > 0, imageSize.height > 0 else { return 1 }
        return max(bounds.width / imageSize.width, bounds.height / imageSize.height)
    }

    /// The maximum zoom.
    static func maxScale(fit: CGFloat) -> CGFloat {
        fit * maxScaleFactor
    }

    /// Where a double tap leads from `current`.
    ///
    /// From the fit scale it zooms to `fill`, or, when the photo already has the ratio of the screen (`fill` equals
    /// `fit`) and would not move, to a fixed multiple of the fit scale. From anywhere else it comes back to `fit`.
    static func doubleTapTargetScale(current: CGFloat, fit: CGFloat, fill: CGFloat) -> CGFloat {
        guard !isZoomed(current: current, fit: fit) else { return fit }
        if fill > fit * zoomedTolerance {
            return min(fill, maxScale(fit: fit))
        }
        return min(fit * sameRatioDoubleTapFactor, maxScale(fit: fit))
    }

    /// Whether the photo is zoomed in, beyond a small tolerance around the fit scale.
    static func isZoomed(current: CGFloat, fit: CGFloat) -> Bool {
        current > fit * zoomedTolerance
    }
}

/// The rules of the drag that dismisses the viewer.
enum DismissRules {
    /// The drag distance, as a fraction of the height, that completes the dismissal progress.
    private static let progressDistanceFraction: CGFloat = 0.4
    /// The drag distance, as a fraction of the height, past which releasing dismisses.
    private static let dismissDistanceFraction: CGFloat = 0.15
    /// The release velocity, in points per second, past which releasing dismisses.
    private static let dismissVelocity: CGFloat = 800

    /// How far the dismissal is, from 0 (not dragged) to 1 (dragged far enough to be gone), in either direction.
    static func progress(translationY: CGFloat, height: CGFloat) -> CGFloat {
        guard height > 0 else { return 0 }
        return min(abs(translationY) / (height * progressDistanceFraction), 1)
    }

    /// Whether releasing the drag dismisses the viewer, by distance or by velocity. Both directions count: down is
    /// the usual gesture, and up behaves the same as in the Photos app.
    static func shouldDismiss(translationY: CGFloat, velocityY: CGFloat, height: CGFloat) -> Bool {
        abs(translationY) > height * dismissDistanceFraction || abs(velocityY) > dismissVelocity
    }

    /// Whether a drag with this velocity is mostly vertical, and so closes the viewer rather than paging.
    static func isMostlyVertical(velocity: CGPoint) -> Bool {
        abs(velocity.y) > abs(velocity.x)
    }

    /// Whether the drag that closes may begin. Not on a zoomed photo, whose drag moves the photo, nor while the pager
    /// is still moving between photos; and only for a mostly vertical drag, a horizontal one pages.
    static func dragShouldBegin(velocity: CGPoint, isZoomed: Bool, isPaging: Bool) -> Bool {
        !isZoomed && !isPaging && isMostlyVertical(velocity: velocity)
    }
}

/// The rules of the horizontal paging between photos.
enum PagingRules {
    /// The index of the shown photo for a horizontal content offset, clamped to the photos. It is the same rule as
    /// the carousel of the feed, so that both agree on the current photo.
    static func index(offsetX: CGFloat, pageWidth: CGFloat, count: Int) -> Int {
        CarouselIndex.index(contentOffsetX: offsetX, pageWidth: pageWidth, pageCount: count)
    }

    /// Whether the pan of the pager may begin. A mostly vertical drag is left to the drag that closes, so that the
    /// two never compete for it, whichever UIKit would otherwise start first.
    static func pagerPanShouldBegin(velocity: CGPoint) -> Bool {
        !DismissRules.isMostlyVertical(velocity: velocity)
    }
}
