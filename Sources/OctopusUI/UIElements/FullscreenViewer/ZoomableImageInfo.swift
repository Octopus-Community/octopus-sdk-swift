//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import UIKit

/// What the fullscreen viewer is asked to show: every photo of the content, the one to open on, and where it comes
/// from on screen, for the transition.
struct ZoomableImageInfo: Equatable {
    /// One photo of the content.
    struct Item: Equatable {
        let url: URL
        /// The full size image, when it is loaded.
        let image: UIImage?
        /// The image as the source shows it, cropped to the ratio of its place. The photo flies with it, so that the
        /// flight starts and ends on what the source shows.
        let transitionImage: UIImage?
    }

    /// The photos of the content, never empty.
    let items: [Item]
    /// The photo to open on, an index of `items`.
    let index: Int
    /// The source the viewer is opened from. Only that source hides while the viewer is open: another copy of the
    /// same photos on screen (a post shown once per comment in a profile) stays in its place.
    let source: ObjectIdentifier?
    /// The key of the VoiceOver label of a photo shown alone, `nil` for none. Several photos are read by position.
    let accessibilityLabelKey: String?
    /// The frame of the source of the transition, in the global coordinate space of SwiftUI, as the source reads it
    /// when it is tapped. The viewer converts it to the window's coordinates. `nil` when it is unknown.
    let sourceFrame: CGRect?
    let sourceCornerRadius: CGFloat
    /// The frame of the source as it is now, in the same space as `sourceFrame`: where the photo flies back to when
    /// the viewer closes, after a rotation or a change of the layout above the source. Ignored by `==`.
    let liveSourceFrame: (@MainActor () -> CGRect?)?
    /// Called with the index of the photo shown when the viewer closes, before it flies back to its source. Ignored
    /// by `==`.
    let onDismiss: ((Int) -> Void)?

    init(items: [Item], index: Int, source: ObjectIdentifier? = nil, accessibilityLabelKey: String? = nil,
         sourceFrame: CGRect?, sourceCornerRadius: CGFloat = 0,
         liveSourceFrame: (@MainActor () -> CGRect?)? = nil, onDismiss: ((Int) -> Void)? = nil) {
        self.items = items
        self.index = index
        self.source = source
        self.accessibilityLabelKey = accessibilityLabelKey
        self.sourceFrame = sourceFrame
        self.sourceCornerRadius = sourceCornerRadius
        self.liveSourceFrame = liveSourceFrame
        self.onDismiss = onDismiss
    }

    /// The url of the photo to open on, `nil` when `index` is not one of `items`.
    var url: URL? { items.indices.contains(index) ? items[index].url : nil }

    /// Whether the viewer is opened from `source` and shows exactly `urls`, the photos of that source: the source is
    /// then hidden while the viewer is open.
    @MainActor
    func isOpened(from source: FullscreenViewerSourceGeometry, showing urls: [URL]) -> Bool {
        self.source == ObjectIdentifier(source) && items.map(\.url) == urls
    }

    static func == (lhs: ZoomableImageInfo, rhs: ZoomableImageInfo) -> Bool {
        lhs.items.map(\.url) == rhs.items.map(\.url)
            && lhs.index == rhs.index
            && lhs.source == rhs.source
            && lhs.accessibilityLabelKey == rhs.accessibilityLabelKey
            && lhs.sourceFrame == rhs.sourceFrame
            && lhs.sourceCornerRadius == rhs.sourceCornerRadius
    }
}

extension ZoomableImageInfo {
    /// One photo, opened from a place showing it cropped to `cachedImage.ratioImage`.
    ///
    /// - Parameters:
    ///   - source: the place, hidden while the viewer is open.
    ///   - sourceFrame: the frame of the place, read now for the flight to the viewer, and again when the viewer
    ///     closes, for the flight back.
    @MainActor
    static func single(url: URL, cachedImage: CachedImage, source: FullscreenViewerSourceGeometry,
                       sourceFrame: @escaping @MainActor () -> CGRect?) -> ZoomableImageInfo {
        ZoomableImageInfo(
            items: [Item(url: url, image: cachedImage.fullSizeImage, transitionImage: cachedImage.ratioImage)],
            index: 0,
            source: ObjectIdentifier(source),
            sourceFrame: sourceFrame(),
            liveSourceFrame: sourceFrame)
    }

    /// Every photo of a carousel, in order, opened on the one at `index`.
    ///
    /// - Parameters:
    ///   - images: the photos of the carousel.
    ///   - index: the photo tapped, an index of `images`.
    ///   - openedImage: the loaded images of the photo tapped.
    ///   - loadedImage: the loaded images of another photo, when its page already has them. The viewer loads the
    ///     others.
    ///   - source: the carousel, hidden while the viewer is open.
    ///   - sourceFrame: the frame of the carousel, the same whatever the photo shown. Read now for the flight to the
    ///     viewer, and again when the viewer closes, for the flight back.
    ///   - onDismiss: called with the index of the photo shown when the viewer closes.
    /// - Returns: `nil` without any photo, or for an index that is not one of them.
    @MainActor
    static func carousel(images: [ImageMedia], index: Int, openedImage: CachedImage,
                         loadedImage: (URL) -> CachedImage?, source: FullscreenViewerSourceGeometry,
                         sourceFrame: @escaping @MainActor () -> CGRect?,
                         onDismiss: @escaping (Int) -> Void) -> ZoomableImageInfo? {
        guard images.indices.contains(index) else { return nil }
        let items = images.enumerated().map { offset, image in
            let loaded = offset == index ? openedImage : loadedImage(image.url)
            return Item(url: image.url, image: loaded?.fullSizeImage, transitionImage: loaded?.ratioImage)
        }
        return ZoomableImageInfo(items: items, index: index, source: ObjectIdentifier(source),
                                 sourceFrame: sourceFrame(), liveSourceFrame: sourceFrame, onDismiss: onDismiss)
    }
}
