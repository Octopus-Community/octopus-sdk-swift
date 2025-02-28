//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import UIKit

private final class Loader: ObservableObject, @unchecked Sendable {
    static let verbose: Bool = false

    @Published var image: UIImage? = nil
    private let url: URL
    private let session: URLSession
    private let cache: ImageCache
    private var storage = [AnyCancellable]()

    init(_ url: URL, cache: ImageCache) {
        self.url = url
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session =  URLSession(configuration: configuration)
        self.cache = cache

        loadImage()
    }

    func loadImage() {
        cache.getFile(url: url) { [weak self] cachedImage in
            guard let self else { return }
            guard let cachedImage else {
                if Self.verbose { print("getting image \(url.imageIdentifier) from server") }
                fetchImageFromRemote()
                return
            }
            if Self.verbose { print("setting image \(url.imageIdentifier) from cache") }
            self.image = cachedImage
        }
    }

    private func fetchImageFromRemote() {
        if Self.verbose { print("Downloading \(url.imageIdentifier) at: \(url) at \(Date())") }
        session.dataTaskPublisher(for: url)
            .map { result -> URLSession.DataTaskPublisher.Output? in result}
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] result in
                guard let result, let image = UIImage(data: result.data) else { return }
                if Self.verbose { print("Image \(url.imageIdentifier) received at \(Date()), storing it in cache") }
                try? cache.store(ImageAndData(imageData: result.data, image: image), url: url)
                self.image = image
            }
            .store(in: &storage)
    }
}

struct AsyncCachedImage<Content: View, Placeholder: View>: View {
    let url: URL
    let placeholder: () -> Placeholder
    let content: (Image) -> Content
    @ObservedObject private var imageLoader: Loader

    init(url: URL, cache: ImageCache,
         @ViewBuilder placeholder: @escaping () -> Placeholder = { EmptyView() },
         @ViewBuilder content: @escaping (Image) -> Content) {
        self.url = url
        self.imageLoader = Loader(url, cache: cache)
        self.placeholder = placeholder
        self.content = content
    }

    var body: some View {
//        ZStack {
//            if let image = imageLoader.image {
//                content(Image(uiImage: image))
//            }
//            placeholder()
//                .opacity(0.5)
//        }
        if let image = imageLoader.image {
            content(Image(uiImage: image))
        } else {
            placeholder()
        }
    }
}
