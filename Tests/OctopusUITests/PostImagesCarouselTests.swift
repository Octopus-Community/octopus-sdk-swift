//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Combine
import SwiftUI
import UIKit
import Testing
@testable import OctopusUI

@Suite
struct PostImagesCarouselTests {
    @Test func heightComesFromFirstImage() {
        // Landscape: the zone takes the ratio of the first image.
        #expect(PostImagesCarouselLayout.height(width: 400, firstImageSize: CGSize(width: 800, height: 400)) == 200)
        // Portrait taller than 4/5: the height is capped by the 4/5 ratio.
        #expect(PostImagesCarouselLayout.height(width: 400, firstImageSize: CGSize(width: 400, height: 800)) == 500)
    }

    @Test func indexSwitchesAtHalfWidth() {
        #expect(CarouselIndex.index(contentOffsetX: 49, pageWidth: 100, pageCount: 3) == 0)
        #expect(CarouselIndex.index(contentOffsetX: 50, pageWidth: 100, pageCount: 3) == 1)
        // Past the last page (bounce): clamped to the last index.
        #expect(CarouselIndex.index(contentOffsetX: 980, pageWidth: 100, pageCount: 3) == 2)
        // Before the first page (bounce): clamped to the first index.
        #expect(CarouselIndex.index(contentOffsetX: -80, pageWidth: 100, pageCount: 3) == 0)
        // No width yet (before the first layout): first page.
        #expect(CarouselIndex.index(contentOffsetX: 50, pageWidth: 0, pageCount: 3) == 0)
    }

    @MainActor
    @Test func positionsAreKeptPerPost() {
        let positions = CarouselPositions()
        positions.set(3, for: "a")
        #expect(positions.index(for: "a") == 3)
        #expect(positions.index(for: "b") == 0)
    }
}

/// The paging scroll view, hosted in a window: its layout follows its width, and it reports the page the user
/// moves to.
@MainActor
struct PagingScrollViewTests {
    @Test func opensOnTheGivenPageWithOnePagePerWidth() async throws {
        let state = PagingState(index: 2)
        let window = makeWindow(width: 300, pageCount: 4, state: state)
        defer { window.isHidden = true }

        let scrollView = try await laidOutScrollView(in: window, contentWidth: 1200)
        #expect(scrollView.contentSize == CGSize(width: 1200, height: 200))
        #expect(scrollView.contentOffset.x == 600)
        #expect(state.writes == 0)
    }

    @Test func reportsTheIndexOnceTheNextPagePassesHalfTheWidth() async throws {
        let state = PagingState(index: 0)
        let window = makeWindow(width: 300, pageCount: 3, state: state)
        defer { window.isHidden = true }
        let scrollView = try await laidOutScrollView(in: window, contentWidth: 900)

        scrollView.contentOffset.x = 149
        #expect(state.index == 0)
        #expect(state.writes == 0)

        scrollView.contentOffset.x = 150
        #expect(state.index == 1)
        #expect(state.lastMoveForward)
        scrollView.contentOffset.x = 200
        #expect(state.writes == 1)

        scrollView.contentOffset.x = 140
        #expect(state.index == 0)
        #expect(!state.lastMoveForward)
        #expect(state.writes == 2)
    }

    @Test func rightToLeftStartsFromTheRightmostPage() async throws {
        let state = PagingState(index: 0)
        let window = makeWindow(width: 300, pageCount: 3, state: state, layoutDirection: .rightToLeft)
        defer { window.isHidden = true }
        let scrollView = try await laidOutScrollView(in: window, contentWidth: 900)

        try await waitUntil { scrollView.contentOffset.x == 600 }
        #expect(scrollView.contentOffset.x == 600)

        scrollView.contentOffset.x = 300
        #expect(state.index == 1)
        #expect(state.lastMoveForward)
    }

    @Test func keepsThePageWhenTheWidthChanges() async throws {
        let state = PagingState(index: 1)
        let window = makeWindow(width: 300, pageCount: 3, state: state)
        defer { window.isHidden = true }
        _ = try await laidOutScrollView(in: window, contentWidth: 900)

        window.frame = CGRect(x: 0, y: 0, width: 400, height: 600)

        let scrollView = try await laidOutScrollView(in: window, contentWidth: 1200)
        #expect(scrollView.contentOffset.x == 400)
        #expect(state.index == 1)
    }

    @Test func keepsTheLastPageWhenTheWidthGrows() async throws {
        let state = PagingState(index: 2)
        let window = makeWindow(width: 300, pageCount: 3, state: state)
        defer { window.isHidden = true }
        _ = try await laidOutScrollView(in: window, contentWidth: 900)

        // UIKit clamps the offset to the old content size before the pages are laid out again: that clamp must not
        // be taken for a swipe.
        window.frame = CGRect(x: 0, y: 0, width: 400, height: 600)

        let scrollView = try await laidOutScrollView(in: window, contentWidth: 1200)
        #expect(scrollView.contentOffset.x == 800)
        #expect(state.index == 2)
        #expect(state.writes == 0)
    }

    @Test func rightToLeftKeepsTheFirstPageWhenTheWidthGrows() async throws {
        let state = PagingState(index: 0)
        let window = makeWindow(width: 300, pageCount: 3, state: state, layoutDirection: .rightToLeft)
        defer { window.isHidden = true }
        _ = try await laidOutScrollView(in: window, contentWidth: 900)

        window.frame = CGRect(x: 0, y: 0, width: 400, height: 600)

        let scrollView = try await laidOutScrollView(in: window, contentWidth: 1200)
        #expect(scrollView.contentOffset.x == 800)
        #expect(state.index == 0)
        #expect(state.writes == 0)
    }

    @Test func carouselRestoresAndRecordsThePositionOfItsPost() async throws {
        let positions = CarouselPositions()
        positions.set(2, for: "post")
        let images = (0..<4).map {
            // Files that do not exist: the pages keep their placeholder, without any network call.
            ImageMedia(url: URL(fileURLWithPath: "/nonexistent/\($0).jpg"), size: CGSize(width: 300, height: 200))
        }
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
        window.rootViewController = UIHostingController(rootView: PostImagesCarouselView(
            postId: "post", images: images, width: 300, zoomableImageInfo: .constant(nil))
            .environment(\.carouselPositions, positions))
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        let scrollView = try await laidOutScrollView(in: window, contentWidth: 1200)
        #expect(scrollView.contentSize.height == 200)
        #expect(scrollView.contentOffset.x == 600)

        scrollView.contentOffset.x = 900
        #expect(positions.index(for: "post") == 3)
    }

    @Test func carouselFollowsAPositionChangedElsewhere() async throws {
        // The same post on another screen (the post detail) moves to another photo while this carousel stays alive.
        let positions = CarouselPositions()
        let images = (0..<4).map {
            ImageMedia(url: URL(fileURLWithPath: "/nonexistent/follow-\($0).jpg"), size: CGSize(width: 300, height: 200))
        }
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
        window.rootViewController = UIHostingController(rootView: PostImagesCarouselView(
            postId: "followed", images: images, width: 300, zoomableImageInfo: .constant(nil))
            .environment(\.carouselPositions, positions))
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let scrollView = try await laidOutScrollView(in: window, contentWidth: 1200)
        scrollView.contentOffset.x = 300
        #expect(positions.index(for: "followed") == 1)

        positions.set(3, for: "followed")

        try await waitUntil { scrollView.contentOffset.x == 900 }
    }

    @Test func positionsReportEachChangeOnce() {
        let positions = CarouselPositions()
        var changes: [String] = []
        let subscription = positions.changes.sink { changes.append("\($0.postId)=\($0.index)") }
        defer { subscription.cancel() }

        positions.set(2, for: "a")
        positions.set(2, for: "a")
        positions.set(0, for: "b")
        positions.set(1, for: "b")

        #expect(changes == ["a=2", "b=1"])
    }

    @Test func pageChangesDoNotRestartTheLoadOfAKeptImage() async throws {
        let created = CreatedLoaders()
        let images = (0..<4).map {
            ImageMedia(url: URL(fileURLWithPath: "/nonexistent/kept-\($0).jpg"), size: CGSize(width: 300, height: 200))
        }
        let loaders = CarouselImageLoaders(makeLoader: { url in
            created.urls.append(url)
            return AsyncCachedImageLoader(url, cache: .content, croppingRatio: nil)
        })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
        window.rootViewController = UIHostingController(rootView: PostImagesCarouselView(
            postId: "kept", images: images, width: 300, zoomableImageInfo: .constant(nil), imageLoaders: loaders)
            .environment(\.carouselPositions, CarouselPositions()))
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let scrollView = try await laidOutScrollView(in: window, contentWidth: 1200)
        #expect(created.urls == [images[0].url, images[1].url])
        let secondLoader = try #require(loaders.loader(for: images[1].url))

        scrollView.contentOffset.x = 300
        try await waitUntil { created.urls.count == 3 }
        scrollView.contentOffset.x = 600
        try await waitUntil { created.urls.count == 4 }

        // Each image got one loader, however many times the pages were rebuilt.
        #expect(created.urls == images.map(\.url))
        #expect(loaders.loader(for: images[1].url) === secondLoader)
        // The first image is two pages away from the shown one: its loader is released.
        #expect(loaders.loader(for: images[0].url) == nil)
    }

    /// UIKit only guarantees that a hosting controller draws the updates of its root view inside the hierarchy of
    /// view controllers: the hosting controller of the pages is a child of the controller of the scroll view.
    @Test func hostsThePagesInAChildController() async throws {
        let window = makeWindow(width: 300, pageCount: 3, state: PagingState(index: 0))
        defer { window.isHidden = true }
        let scrollView = try await laidOutScrollView(in: window, contentWidth: 900)

        let controller = try #require(scrollView.next as? PagingViewController<Color>)
        #expect(controller.hostingController.parent === controller)
        #expect(controller.hostingController.view.superview === scrollView)
    }

    /// A page that shows other data once the scroll view is on screen (a photo whose loader is created when the user
    /// gets close to it) draws that data.
    @Test func drawsAPageThatChangesAfterAppearing() async throws {
        let model = PageColorModel()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
        window.rootViewController = UIHostingController(rootView: ColoredPagingScreen(model: model))
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        _ = try await laidOutScrollView(in: window, contentWidth: 600)
        // The scroll view, 200 points high, is centred in the window.
        let firstPagePoint = CGPoint(x: 150, y: 300)
        // Drawn in gray first.
        try await waitUntil { Self.pixel(of: window, at: firstPagePoint).red < 200 }

        model.firstPageColor = .red

        try await waitUntil { Self.isRed(Self.pixel(of: window, at: firstPagePoint)) }
    }

    /// The way back from the fullscreen viewer: the carousel records the photo the viewer closed on in its state,
    /// outside of any gesture of the scroll view, and the scroll view goes there at once, without reporting it back.
    @Test func goesToAPageSetFromOutsideWithoutAnimation() async throws {
        let model = PagingModel()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
        window.rootViewController = UIHostingController(rootView: ObservedPagingScreen(model: model))
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let scrollView = try await laidOutScrollView(in: window, contentWidth: 1200)
        #expect(scrollView.contentOffset.x == 0)

        model.index = 3

        try await waitUntil { scrollView.contentOffset.x == 900 }
        #expect(!scrollView.isDecelerating)
        #expect(model.writes == 0)
    }

    private func makeWindow(width: CGFloat, pageCount: Int, state: PagingState,
                            layoutDirection: LayoutDirection = .leftToRight) -> UIWindow {
        // The test host runs without scenes, so the window is attached to the screen directly.
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 600))
        let view = PagingScrollView(
            pageCount: pageCount,
            currentIndex: Binding(get: { state.index }, set: { state.index = $0; state.writes += 1 }),
            lastMoveForward: Binding(get: { state.lastMoveForward }, set: { state.lastMoveForward = $0 })
        ) { _ in
            Color.gray
        }
        .frame(height: 200)
        .environment(\.layoutDirection, layoutDirection)
        window.rootViewController = UIHostingController(rootView: view)
        window.makeKeyAndVisible()
        return window
    }

    /// The scroll view in the window, once it has laid its pages out for the given content width.
    private func laidOutScrollView(in window: UIWindow, contentWidth: CGFloat) async throws -> PagingUIScrollView {
        try await waitUntil { scrollView(in: window)?.contentSize.width == contentWidth }
        return try #require(scrollView(in: window))
    }

    private static func pixel(of window: UIWindow, at point: CGPoint) -> (red: UInt8, green: UInt8, blue: UInt8) {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        // The test host has no render server: draw the layers rather than a snapshot of the screen.
        window.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { context in
            window.layer.render(in: context.cgContext)
        }
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let cgImage = image.cgImage,
              let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return (0, 0, 0)
        }
        context.draw(cgImage, in: CGRect(x: -point.x, y: point.y - CGFloat(cgImage.height) + 1,
                                         width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
        return (pixel[0], pixel[1], pixel[2])
    }

    private static func isRed(_ pixel: (red: UInt8, green: UInt8, blue: UInt8)) -> Bool {
        pixel.red > 200 && pixel.green < 100 && pixel.blue < 100
    }

    private func scrollView(in view: UIView) -> PagingUIScrollView? {
        if let scrollView = view as? PagingUIScrollView { return scrollView }
        for subview in view.subviews {
            if let scrollView = scrollView(in: subview) { return scrollView }
        }
        return nil
    }
}

/// The loaders of the carousel pages: kept across page changes, and the source of the image the tap opens.
@MainActor
struct CarouselImageLoadersTests {
    @Test func keepsTheLoaderOfAnImageAcrossPageChanges() throws {
        let created = CreatedLoaders()
        let urls = (0..<4).map { URL(fileURLWithPath: "/nonexistent/loaders-\($0).jpg") }
        let loaders = CarouselImageLoaders(makeLoader: { url in
            created.urls.append(url)
            return AsyncCachedImageLoader(url, cache: .content, croppingRatio: nil)
        })

        // First page shown, then the second, then the third: the shown page and its neighbours keep a loader.
        loaders.keep([urls[0], urls[1]])
        let secondLoader = try #require(loaders.loader(for: urls[1]))
        loaders.keep([urls[0], urls[1], urls[2]])
        #expect(loaders.loader(for: urls[1]) === secondLoader)
        let thirdLoader = try #require(loaders.loader(for: urls[2]))
        loaders.keep([urls[1], urls[2], urls[3]])
        #expect(loaders.loader(for: urls[1]) === secondLoader)
        #expect(loaders.loader(for: urls[2]) === thirdLoader)

        #expect(loaders.loader(for: urls[0]) == nil)
        #expect(created.urls == urls)
    }

    @Test func givesTheImageOfTheLoader() throws {
        let url = URL(fileURLWithPath: "/nonexistent/loaded.jpg")
        let image = CachedImage(ratioImage: Self.makeImage(), fullSizeImage: Self.makeImage())
        let loaders = CarouselImageLoaders(makeLoader: {
            AsyncCachedImageLoader($0, cache: .content, croppingRatio: nil)
        })
        loaders.keep([url])
        try #require(loaders.loader(for: url)).image = image

        let received = ReceivedImage()
        loaders.cachedImage(for: url) { received.image = $0 }
        #expect(received.image?.fullSizeImage === image.fullSizeImage)
    }

    /// The page may not have reported its image (a hosted view that never appeared), or its loader may be gone: the
    /// tap still opens an image the cache holds in memory, synchronously.
    @Test func fallsBackOnTheCacheWithoutALoader() throws {
        let cache = ImageCache(subfolder: "CarouselImageLoadersTests", ramCapacity: 1024 * 1024, diskCapacity: 0)
        let url = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString).png")
        let image = Self.makeImage()
        try cache.store(ImageAndData(imageData: try #require(image.pngData()), image: image), url: url)
        let loaders = CarouselImageLoaders(cache: cache)

        let received = ReceivedImage()
        loaders.cachedImage(for: url) { received.image = $0 }
        #expect(received.image?.fullSizeImage === image)
    }

    private static func makeImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 4, height: 5)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 5))
        }
    }
}

@MainActor
private final class CreatedLoaders {
    var urls: [URL] = []
}

@MainActor
private final class ReceivedImage {
    var image: CachedImage?
}

@MainActor
private final class PagingState {
    var index: Int
    var lastMoveForward = false
    var writes = 0

    init(index: Int) {
        self.index = index
    }
}

@MainActor
private final class PageColorModel: ObservableObject {
    @Published var firstPageColor = Color.gray
}

private struct ColoredPagingScreen: View {
    @ObservedObject var model: PageColorModel
    @State private var index = 0
    @State private var lastMoveForward = true

    var body: some View {
        PagingScrollView(pageCount: 2, currentIndex: $index, lastMoveForward: $lastMoveForward) { page in
            page == 0 ? model.firstPageColor : Color.blue
        }
        .frame(height: 200)
    }
}

@MainActor
private final class PagingModel: ObservableObject {
    @Published var index = 0
    var writes = 0
}

private struct ObservedPagingScreen: View {
    @ObservedObject var model: PagingModel
    @State private var lastMoveForward = true

    var body: some View {
        PagingScrollView(
            pageCount: 4,
            currentIndex: Binding(get: { model.index }, set: { model.index = $0; model.writes += 1 }),
            lastMoveForward: $lastMoveForward
        ) { _ in
            Color.gray
        }
        .frame(height: 200)
    }
}
