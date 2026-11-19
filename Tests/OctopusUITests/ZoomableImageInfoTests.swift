//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
import UIKit
@testable import OctopusUI

/// The requests the sources build for the fullscreen viewer: its photos, the one to open on, and where it flies from.
@MainActor
struct ZoomableImageInfoTests {
    @Test func carouselTapBuildsEveryItem() throws {
        let images = (0..<4).map {
            ImageMedia(url: URL(string: "https://example.com/\($0).jpg")!, size: CGSize(width: 300, height: 200))
        }
        let opened = CachedImage(ratioImage: makeImage(), fullSizeImage: makeImage())
        let neighbour = CachedImage(ratioImage: makeImage(), fullSizeImage: makeImage())
        let frame = CGRect(x: 0, y: 100, width: 300, height: 200)
        let dismissed = Dismissals()
        let source = FullscreenViewerSourceGeometry()

        let built = ZoomableImageInfo.carousel(
            images: images, index: 2, openedImage: opened,
            loadedImage: { $0 == images[1].url ? neighbour : nil },
            source: source,
            sourceFrame: { frame },
            onDismiss: { dismissed.indexes.append($0) })
        let info = try #require(built)

        #expect(info.items.map(\.url) == images.map(\.url))
        #expect(info.index == 2)
        #expect(info.url == images[2].url)
        #expect(info.items[2].image === opened.fullSizeImage)
        #expect(info.items[2].transitionImage === opened.ratioImage)
        #expect(info.items[1].image === neighbour.fullSizeImage)
        #expect(info.items[1].transitionImage === neighbour.ratioImage)
        #expect(info.items[0].image == nil)
        #expect(info.items[3].image == nil)
        // The zone of the carousel, whatever the photo shown.
        #expect(info.sourceFrame == frame)
        #expect(info.liveSourceFrame?() == frame)
        #expect(info.sourceCornerRadius == 0)
        #expect(info.isOpened(from: source, showing: images.map(\.url)))
        #expect(!info.isOpened(from: source, showing: [images[2].url]))
        info.onDismiss?(3)
        #expect(dismissed.indexes == [3])

        // Never an empty request, nor an index outside of the photos.
        let empty = ZoomableImageInfo.carousel(
            images: [], index: 0, openedImage: opened, loadedImage: { _ in nil }, source: source, sourceFrame: { nil },
            onDismiss: { _ in })
        #expect(empty == nil)
        let outOfRange = ZoomableImageInfo.carousel(
            images: images, index: 4, openedImage: opened, loadedImage: { _ in nil }, source: source, sourceFrame: { nil },
            onDismiss: { _ in })
        #expect(outOfRange == nil)
    }

    @Test func singleImageFliesWithItsCroppedImage() {
        let url = URL(string: "https://example.com/single.jpg")!
        let cached = CachedImage(ratioImage: makeImage(), fullSizeImage: makeImage())
        let frame = CGRect(x: 0, y: 100, width: 300, height: 200)

        let source = FullscreenViewerSourceGeometry()

        let info = ZoomableImageInfo.single(url: url, cachedImage: cached, source: source, sourceFrame: { frame })

        #expect(info.items.map(\.url) == [url])
        #expect(info.items[0].image === cached.fullSizeImage)
        #expect(info.items[0].transitionImage === cached.ratioImage)
        #expect(info.index == 0)
        #expect(info.sourceFrame == frame)
        #expect(info.isOpened(from: source, showing: [url]))
        #expect(info.accessibilityLabelKey == nil)
    }

    /// The same photo can be on screen twice (a post shown once per comment in a profile): only the copy tapped hides
    /// while the viewer is open, the other one stays in its place.
    @Test func onlyTheTappedCopyOfAPhotoHides() {
        let url = URL(string: "https://example.com/repeated.jpg")!
        let cached = CachedImage(ratioImage: makeImage(), fullSizeImage: makeImage())
        let tapped = FullscreenViewerSourceGeometry()
        let other = FullscreenViewerSourceGeometry()

        let info = ZoomableImageInfo.single(url: url, cachedImage: cached, source: tapped, sourceFrame: { nil })

        #expect(info.isOpened(from: tapped, showing: [url]))
        #expect(!info.isOpened(from: other, showing: [url]))
        // A source that shows other photos since it was tapped is not the one in the viewer any more.
        #expect(!info.isOpened(from: tapped, showing: [URL(string: "https://example.com/other.jpg")!]))
    }

    @Test func avatarFliesFromItsCircle() {
        let url = URL(string: "https://example.com/avatar.jpg")!
        let image = makeImage()

        let source = FullscreenViewerSourceGeometry()

        let info = ZoomableAuthorAvatarView.zoomableImageInfo(
            url: url, image: image, source: source, frame: { CGRect(x: 10, y: 20, width: 120, height: 80) })

        // The largest circle centred in the frame: the one the mask draws.
        #expect(info.sourceFrame == CGRect(x: 30, y: 20, width: 80, height: 80))
        #expect(info.liveSourceFrame?() == CGRect(x: 30, y: 20, width: 80, height: 80))
        #expect(info.sourceCornerRadius == 40)
        #expect(info.items[0].image === image)
        #expect(info.items[0].transitionImage == nil)
        #expect(info.isOpened(from: source, showing: [url]))
        // VoiceOver reads the picture as on the profile.
        #expect(info.accessibilityLabelKey == "Accessibility.Profile.Picture")
        let withoutFrame = ZoomableAuthorAvatarView.zoomableImageInfo(
            url: url, image: image, source: source, frame: { nil })
        #expect(withoutFrame.sourceFrame == nil)
    }

    @Test func requestURLIsNilOutsideOfTheItems() {
        let item = ZoomableImageInfo.Item(url: URL(string: "https://example.com/a.jpg")!, image: nil,
                                          transitionImage: nil)
        #expect(ZoomableImageInfo(items: [item], index: 1, sourceFrame: nil).url == nil)
        #expect(ZoomableImageInfo(items: [], index: 0, sourceFrame: nil).url == nil)
    }
}

@MainActor
private final class Dismissals {
    var indexes: [Int] = []
}

@MainActor
private func makeImage() -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: CGSize(width: 400, height: 200), format: format).image { context in
        UIColor.red.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 400, height: 200))
    }
}
