//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import UIKit
import os

struct CachedImage {
    /// The image at the asked ratio
    let ratioImage: UIImage
    /// The full size image
    let fullSizeImage: UIImage
}

/// Loads an image from the cache, else from the network, as soon as it is created. Releasing it cancels the download.
///
/// Its state is only touched on the main actor, where SwiftUI and the views that keep loaders also release them: a
/// cache miss reported from a background queue must not start a download, nor drop the last reference, off main.
@MainActor
final class AsyncCachedImageLoader: ObservableObject {
    nonisolated static let verbose: Bool = false

    /// Shared by every loader: a session per loader was never invalidated, so each one leaked with its delegate
    /// queue. The images are cached by `ImageCache`, not by the URL loading system, so the session keeps no cache.
    ///
    /// The image host serves HTTP/1.1, where the session runs at most `httpMaximumConnectionsPerHost` downloads at
    /// once and queues the others. iOS defaults it to 4; 6 is what browsers allow per host over HTTP/1.1, and a bit
    /// more than the 5 the Android SDK's image loader runs.
    nonisolated private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpMaximumConnectionsPerHost = 6
        return URLSession(configuration: configuration)
    }()

    @Published var image: CachedImage?
    /// Whether the last download gave no image: a network error, or an answer that is not an image. Cleared by
    /// `retry()`.
    @Published private(set) var didFail = false
    let url: URL
    private let cache: ImageCache
    private let croppingRatio: Double?
    private var storage = [AnyCancellable]()

    init(_ url: URL, cache: ImageCache, croppingRatio: Double?) {
        self.url = url
        self.cache = cache
        self.croppingRatio = croppingRatio

        loadImage()
    }

    func loadImage() {
        cache.getFile(url: url, croppingRatio: croppingRatio) { [weak self] cachedImage in
            guard let self else { return }
            guard let cachedImage else {
                if #available(iOS 14, *) {
                    if Self.verbose {
                        Logger.images.trace("getting image \(self.url.imageIdentifier) from server")
                    }
                }
                fetchImageFromRemote()
                return
            }
            if #available(iOS 14, *) {
                if Self.verbose { Logger.images.trace("setting image \(self.url.imageIdentifier) from cache") }
            }

            self.image = cachedImage
        }
    }

    /// Loads the image again after a failed download.
    func retry() {
        guard didFail else { return }
        didFail = false
        loadImage()
    }

    private func fetchImageFromRemote() {
        if #available(iOS 14, *) {
            if Self.verbose { Logger.images.trace("Downloading \(self.url.imageIdentifier) at: \(self.url) at \(Date())") }
        }
        Self.download(url)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] data in
                guard let self else { return }
                guard let data, let image = UIImage(data: data) else {
                    didFail = true
                    return
                }
                if #available(iOS 14, *) {
                    if Self.verbose {
                        Logger.images.trace("Image \(self.url.imageIdentifier) received at \(Date()), storing it in cache")
                    }
                }
                try? cache.store(ImageAndData(imageData: data, image: image), url: url)
                cache.getFile(url: url, croppingRatio: croppingRatio) { [weak self] cachedImage in
                    self?.image = cachedImage
                }
            }
            .store(in: &storage)
    }

    /// Built outside the main actor: its operators run on the session's queue.
    nonisolated private static func download(_ url: URL) -> AnyPublisher<Data?, Never> {
        session.dataTaskPublisher(for: url)
            .map { Optional($0.data) }
            .replaceError(with: nil)
            .eraseToAnyPublisher()
    }
}

struct AsyncCachedImage<Content: View, Placeholder: View>: View {
    let url: URL
    let placeholder: () -> Placeholder
    let content: (CachedImage) -> Content
    @ObservedObject private var imageLoader: AsyncCachedImageLoader

    /// Starts a new load on every init: a view rebuilt with the same url downloads it again. A view that is rebuilt
    /// often and keeps its url should keep its loader and use `init(loader:placeholder:content:)`.
    init(url: URL, cache: ImageCache,
         croppingRatio: Double? = nil,
         @ViewBuilder placeholder: @escaping () -> Placeholder = { EmptyView() },
         @ViewBuilder content: @escaping (CachedImage) -> Content) {
        self.init(
            loader: AsyncCachedImageLoader(url, cache: cache, croppingRatio: croppingRatio),
            placeholder: placeholder,
            content: content)
    }

    /// Shows the image of a loader the caller keeps, so that a rebuild of the view does not restart the load.
    init(loader: AsyncCachedImageLoader,
         @ViewBuilder placeholder: @escaping () -> Placeholder = { EmptyView() },
         @ViewBuilder content: @escaping (CachedImage) -> Content) {
        self.url = loader.url
        self.imageLoader = loader
        self.placeholder = placeholder
        self.content = content
    }

    var body: some View {
//        ZStack {
//            if let image = imageLoader.image {
//                content(image)
//            }
//            placeholder()
//                .opacity(0.5)
//        }
        if let image = imageLoader.image {
            content(image)
        } else {
            placeholder()
        }
    }
}
