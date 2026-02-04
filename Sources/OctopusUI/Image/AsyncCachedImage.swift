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

private final class Loader: ObservableObject, @unchecked Sendable {
    static let verbose: Bool = false

    @Published var image: CachedImage? = nil
    private let url: URL
    private let session: URLSession
    private let cache: ImageCache
    private let croppingRatio: Double?
    private var storage = [AnyCancellable]()

    init(_ url: URL, cache: ImageCache, croppingRatio: Double?) {
        self.url = url
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session =  URLSession(configuration: configuration)
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

    private func fetchImageFromRemote() {
        if #available(iOS 14, *) {
            if Self.verbose { Logger.images.trace("Downloading \(self.url.imageIdentifier) at: \(self.url) at \(Date())") }
        }
        session.dataTaskPublisher(for: url)
            .map { result -> URLSession.DataTaskPublisher.Output? in result}
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                guard let self, let result, let image = UIImage(data: result.data) else { return }
                if #available(iOS 14, *) {
                    if Self.verbose {
                        Logger.images.trace("Image \(self.url.imageIdentifier) received at \(Date()), storing it in cache")
                    }
                }
                try? cache.store(ImageAndData(imageData: result.data, image: image), url: url)
                cache.getFile(url: url, croppingRatio: croppingRatio) { cachedImage in
                    self.image = cachedImage
                }
            }
            .store(in: &storage)
    }
}

struct AsyncCachedImage<Content: View, Placeholder: View>: View {
    let url: URL
    let placeholder: () -> Placeholder
    let content: (CachedImage) -> Content
    @ObservedObject private var imageLoader: Loader

    init(url: URL, cache: ImageCache,
         croppingRatio: Double? = nil,
         @ViewBuilder placeholder: @escaping () -> Placeholder = { EmptyView() },
         @ViewBuilder content: @escaping (CachedImage) -> Content) {
        self.url = url
        self.imageLoader = Loader(url, cache: cache, croppingRatio: croppingRatio)
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
