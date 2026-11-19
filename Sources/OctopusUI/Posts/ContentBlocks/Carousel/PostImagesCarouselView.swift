//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

/// Size of the zone of the images of a post.
enum PostImagesCarouselLayout {
    /// The narrowest ratio (width / height) of the zone: a taller first image is cropped to it.
    static let minAspectRatio: CGFloat = 4 / 5

    /// The height of the zone: it takes the ratio of the first image, capped at `minAspectRatio`. The other images
    /// fill it.
    static func height(width: CGFloat, firstImageSize: CGSize) -> CGFloat {
        // An image without a size gives no ratio: keep the zone square rather than flat or infinite.
        guard firstImageSize.width > 0, firstImageSize.height > 0 else { return width }
        return width / max(firstImageSize.width / firstImageSize.height, minAspectRatio)
    }
}

/// The images of a post, one at a time, swiped horizontally, with dots below them and, from two images, a
/// "current / total" counter in the top right corner.
struct PostImagesCarouselView: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.carouselPositions) private var positions

    let postId: String
    /// The images, never empty.
    let images: [ImageMedia]
    let width: CGFloat
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    /// Replaces the fullscreen viewer when the shown image is tapped, `nil` to keep it. Swiping is unchanged.
    let imageTapOverride: (() -> Void)?

    /// The page the user moved to. Tied to the post, so that a view reused for another post starts from the
    /// position of that post.
    @State private var shownPage: ShownPage?
    @State private var lastMoveForward = true
    /// The loaders of the shown page and its neighbours, kept while the pages are rebuilt.
    @State private var imageLoaders: CarouselImageLoaders
    @State private var sourceGeometry = FullscreenViewerSourceGeometry()

    /// - Parameter imageLoaders: where the pages keep the loaders of their images, new ones when nil. Only the first
    ///   value given to a view is used, like any state.
    init(postId: String, images: [ImageMedia], width: CGFloat, zoomableImageInfo: Binding<ZoomableImageInfo?>,
         imageLoaders: CarouselImageLoaders? = nil, imageTapOverride: (() -> Void)? = nil) {
        self.postId = postId
        self.images = images
        self.width = width
        self._zoomableImageInfo = zoomableImageInfo
        self.imageTapOverride = imageTapOverride
        // Created here rather than as the default value: the pods compile in Swift 5 mode, where a default value is
        // evaluated outside the main actor and cannot call the main actor initializer of the loaders.
        self._imageLoaders = State(initialValue: imageLoaders ?? CarouselImageLoaders())
    }

    private struct ShownPage: Equatable {
        let postId: String
        let index: Int
    }

    private enum Dimensions {
        static let indicatorTopPadding: CGFloat = 8
        static let counterInset: CGFloat = 8
        static let counterHorizontalPadding: CGFloat = 10
        static let counterVerticalPadding: CGFloat = 4
        static let counterBackgroundOpacity: Double = 0.5
    }

    private var currentIndex: Int {
        let index = if let shownPage, shownPage.postId == postId {
            shownPage.index
        } else {
            positions.index(for: postId)
        }
        return min(max(index, 0), max(images.count - 1, 0))
    }

    var body: some View {
        let index = currentIndex
        let theme = theme
        let images = images
        let imageLoaders = imageLoaders
        // Only the shown page and its neighbours download their image.
        imageLoaders.keep(images.indices.filter { abs($0 - index) <= 1 }.map { images[$0].url })
        return VStack(spacing: 0) {
            PagingScrollView(
                pageCount: images.count,
                currentIndex: Binding(get: { index }, set: { show($0) }),
                lastMoveForward: $lastMoveForward
            ) { page in
                CarouselPage(
                    loader: imageLoaders.loader(for: images[page].url),
                    placeholderColor: theme.colors.gray200)
            }
            .frame(height: PostImagesCarouselLayout.height(width: width, firstImageSize: images[0].size))
            .overlay(counter(index: index), alignment: .topTrailing)
            .fullscreenViewerSource(
                sourceGeometry,
                isInViewer: zoomableImageInfo?.isOpened(from: sourceGeometry, showing: images.map(\.url)) ?? false)
            .contentShape(Rectangle())
            .onTapGesture { openImage(at: index) }

            if let state = PageIndicatorState.make(
                pageCount: images.count, currentIndex: index, lastMoveForward: lastMoveForward) {
                PageIndicatorView(state: state)
                    .padding(.top, Dimensions.indicatorTopPadding)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isImage)
        .accessibilityValueInBundle("Accessibility.Carousel.Position_index:\(index + 1)_count:\(images.count)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: show(index + 1)
            case .decrement: show(index - 1)
            @unknown default: break
            }
        }
        .accessibilityAction { openImage(at: index) }
        // The same post moved on another screen while this carousel stayed alive (the feed under a post detail).
        .onReceive(positions.changes) { change in
            guard change.postId == postId else { return }
            follow(change.index)
        }
    }

    @ViewBuilder
    private func counter(index: Int) -> some View {
        if PageIndicatorState.showsCounter(pageCount: images.count) {
            Text("Post.Carousel.Counter_index:\(index + 1)_count:\(images.count)", bundle: .module)
                .font(theme.fonts.caption1)
                .foregroundColor(.white)
                .padding(.horizontal, Dimensions.counterHorizontalPadding)
                .padding(.vertical, Dimensions.counterVerticalPadding)
                .background(Capsule().fill(Color.black.opacity(Dimensions.counterBackgroundOpacity)))
                .padding(Dimensions.counterInset)
                .allowsHitTesting(false)
        }
    }

    private func show(_ index: Int) {
        let index = min(max(index, 0), images.count - 1)
        guard index != currentIndex else { return }
        follow(index)
        positions.set(index, for: postId)
    }

    /// Shows the page another carousel of the same post moved to, without recording it again.
    private func follow(_ index: Int) {
        let index = min(max(index, 0), images.count - 1)
        let previousIndex = currentIndex
        guard index != previousIndex else { return }
        let moveForward = index > previousIndex
        if moveForward != lastMoveForward {
            lastMoveForward = moveForward
        }
        shownPage = ShownPage(postId: postId, index: index)
    }

    private func openImage(at index: Int) {
        if let imageTapOverride {
            imageTapOverride()
            return
        }
        let images = images
        let url = images[index].url
        let imageLoaders = imageLoaders
        let sourceGeometry = sourceGeometry
        let zoomableImageInfo = $zoomableImageInfo
        // Same as the single image: nothing to open before the image is loaded.
        imageLoaders.cachedImage(for: url) { cachedImage in
            zoomableImageInfo.wrappedValue = .carousel(
                images: images, index: index, openedImage: cachedImage,
                loadedImage: { imageLoaders.loader(for: $0)?.image },
                source: sourceGeometry,
                // Read once the image is loaded, which can be late: the zone may have moved since the tap.
                sourceFrame: { sourceGeometry.frame },
                // Moves to the photo shown before it flies back, without animation: the carousel is hidden until the
                // photo has landed. The zone, where the photo lands, is the same whatever the photo.
                onDismiss: { show($0) })
        }
    }
}

/// The loaders of the images of a carousel, by url. Not observed: each page observes its own loader.
///
/// They live here rather than in the pages because the pages are rebuilt on every page change: a loader created by
/// the page would restart its download each time.
@MainActor
final class CarouselImageLoaders {
    typealias MakeLoader = @MainActor (URL) -> AsyncCachedImageLoader

    private var loaders: [URL: AsyncCachedImageLoader] = [:]
    private let cache: ImageCache
    private let makeLoader: MakeLoader

    init(cache: ImageCache = .content, makeLoader: MakeLoader? = nil) {
        self.cache = cache
        self.makeLoader = makeLoader ?? {
            AsyncCachedImageLoader($0, cache: cache, croppingRatio: PostImagesCarouselLayout.minAspectRatio)
        }
    }

    /// Keeps a loader for each of `urls`, creating the missing ones, and releases the others, which cancels their
    /// download. The images stay in the cache, so a page that comes back gets its image without a new download.
    func keep(_ urls: [URL]) {
        let kept = Set(urls)
        loaders = loaders.filter { kept.contains($0.key) }
        for url in urls where loaders[url] == nil {
            loaders[url] = makeLoader(url)
        }
    }

    /// The loader of `url`, if it is kept.
    func loader(for url: URL) -> AsyncCachedImageLoader? {
        loaders[url]
    }

    /// Gives the image of `url` once it is loaded, and nothing before.
    ///
    /// The image comes from the loader of its page when it has it. Otherwise it comes from the cache, which answers
    /// synchronously when it holds the image in memory: the loader may not have published the image yet, or may be
    /// gone.
    func cachedImage(for url: URL, completion: @escaping @MainActor @Sendable (CachedImage) -> Void) {
        if let image = loaders[url]?.image {
            completion(image)
            return
        }
        cache.getFile(url: url, croppingRatio: PostImagesCarouselLayout.minAspectRatio) { cachedImage in
            guard let cachedImage else { return }
            // The cache gives an image on the main queue: synchronously on a hit in memory, dispatched otherwise.
            if Thread.isMainThread {
                MainActor.assumeIsolated { completion(cachedImage) }
            } else {
                DispatchQueue.main.async { completion(cachedImage) }
            }
        }
    }
}

/// One image of the carousel, filling its page. Without a loader, the page is too far from the shown one to load
/// its image.
private struct CarouselPage: View {
    let loader: AsyncCachedImageLoader?
    let placeholderColor: Color

    var body: some View {
        if let loader {
            AsyncCachedImage(
                loader: loader,
                placeholder: { placeholderColor },
                content: { cachedImage in
                    Image(uiImage: cachedImage.ratioImage)
                        .resizable()
                        .scaledToFill()
                        // At the size of the page, so that the pinch takes the page and its copy is cropped like it.
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .inPlacePinchZoom(image: cachedImage.ratioImage)
                })
        } else {
            placeholderColor
        }
    }
}

#Preview("8 images") {
    PostImagesCarouselView(
        postId: "p1",
        images: (0..<8).map {
            // The image cache is keyed by the last path component: each image needs its own.
            ImageMedia(
                url: URL(string: "https://placehold.co/700x\(750 + $0).png")!,
                size: CGSize(width: 700, height: 750 + CGFloat($0)))
        },
        width: 393,
        zoomableImageInfo: .constant(nil))
    .mockEnvironmentForPreviews()
}
