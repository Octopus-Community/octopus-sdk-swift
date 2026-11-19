//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import UIKit
@testable import OctopusUI

/// The cache reads its files on a background queue. Views release their loaders on main as they scroll away, so a
/// loader must never be touched, nor kept alive, from that queue.
@MainActor
final class AsyncCachedImageLoaderTests {
    private let cache: ImageCache
    /// Where the tests write the images the loader downloads.
    private let sourceFolder: URL

    init() throws {
        let name = "AsyncCachedImageLoaderTests-\(UUID().uuidString)"
        cache = ImageCache(subfolder: name, ramCapacity: 1024 * 1024, diskCapacity: 1024 * 1024)
        sourceFolder = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: sourceFolder, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: cache.imageFolder)
        try? FileManager.default.removeItem(at: sourceFolder)
    }

    @Test func cacheMissIsDeliveredOnTheMainThread() async {
        let (image, onMainThread) = await withCheckedContinuation { continuation in
            cache.getFile(url: missingFileUrl(), croppingRatio: nil) { image in
                continuation.resume(returning: (image, Thread.isMainThread))
            }
        }

        #expect(image == nil)
        #expect(onMainThread)
    }

    @Test func loaderDownloadsTheImageOnACacheMiss() async throws {
        let url = try writeImageFile()
        let loader = AsyncCachedImageLoader(url, cache: cache, croppingRatio: nil)

        try await waitUntil { loader.image != nil }

        #expect(loader.image?.fullSizeImage.size == CGSize(width: 4, height: 4))
    }

    @Test func failedDownloadIsReportedAndCanBeRetried() async throws {
        let url = missingFileUrl()
        let loader = AsyncCachedImageLoader(url, cache: cache, croppingRatio: nil)
        #expect(!loader.didFail)

        try await waitUntil { loader.didFail }
        #expect(loader.image == nil)

        // The file is there now: the retry finds it.
        try writeImageFile(at: url)
        loader.retry()
        #expect(!loader.didFail)
        try await waitUntil { loader.image != nil }
        #expect(!loader.didFail)
    }

    @Test func answerThatIsNotAnImageIsAFailure() async throws {
        let url = sourceFolder.appendingPathComponent("not-an-image-\(UUID().uuidString).png")
        try Data("<html>Not found</html>".utf8).write(to: url)
        let loader = AsyncCachedImageLoader(url, cache: cache, croppingRatio: nil)

        try await waitUntil { loader.didFail }
        #expect(loader.image == nil)
    }

    @Test func loaderReleasedDuringACacheMissIsFreedAtOnce() {
        weak var weakLoader: AsyncCachedImageLoader?
        do {
            let loader = AsyncCachedImageLoader(missingFileUrl(), cache: cache, croppingRatio: nil)
            weakLoader = loader
        }

        // The pending cache read only holds the loader weakly, so the loader is freed on main, where it is released.
        #expect(weakLoader == nil)
    }

    private func missingFileUrl() -> URL {
        sourceFolder.appendingPathComponent("missing-\(UUID().uuidString).png")
    }

    /// Writes a 4x4 PNG under a unique name, so that the cache misses it and the loader downloads it.
    private func writeImageFile() throws -> URL {
        let url = sourceFolder.appendingPathComponent("image-\(UUID().uuidString).png")
        try writeImageFile(at: url)
        return url
    }

    private func writeImageFile(at url: URL) throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4), format: format)
            .image { context in
                UIColor.red.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
            }
        try #require(image.pngData()).write(to: url)
    }

    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else {
                Issue.record("Timed out")
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}
