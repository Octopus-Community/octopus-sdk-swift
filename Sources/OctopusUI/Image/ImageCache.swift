//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import UIKit
import os

final class ImageCache: @unchecked Sendable {
    static let profile = ImageCache(subfolder: "profile",
                                    ramCapacity: 50 * 1024 * 1024,      // 50Mb
                                    diskCapacity: 100 * 1024 * 1024)    // 100Mb

    static let content = ImageCache(subfolder: "content",
                                    ramCapacity: 200 * 1024 * 1024,     // 200Mb
                                    diskCapacity: 500 * 1024 * 1024)    // 500Mb

    private let imageFolder: URL
    private let fileManager: FileManager = FileManager.default
    private let ramCache: NSCache<NSString, UIImage> = NSCache()

    init(subfolder: String, ramCapacity: Int, diskCapacity: UInt64) {
        let rootFolder = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first ??
            fileManager.temporaryDirectory
        imageFolder = rootFolder.appendingPathComponent("Images").appendingPathComponent(subfolder)
        ramCache.totalCostLimit = ramCapacity
        do {
            try fileManager.createDirectory(at: imageFolder, withIntermediateDirectories: true)
            try cleanup(targetSize: diskCapacity)
        } catch {
            if #available(iOS 14, *) { Logger.images.trace("ImageCache init error: \(error)") }
        }
    }

    func getFile(url: URL, croppingRatio: Double?, completion: @escaping @Sendable (CachedImage?) -> Void) {
        @Sendable func createCachedImage(_ fullSizeImage: UIImage) -> CachedImage {
            CachedImage(ratioImage: getCroppedImageIfNeeded(fullSizeImage, croppingRatio: croppingRatio, url: url),
                        fullSizeImage: fullSizeImage)
        }
        let fileName = url.imageIdentifier
        // look in ram first
        if let image = ramCache.object(forKey: fileName as NSString) {
            completion(createCachedImage(image))
            return
        }

        // if not found in ram, look on FileSystem
        let fileUrl = imageFolder.appendingPathComponent(fileName)
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let data = try? Data(contentsOf: fileUrl),
                  let image = UIImage(data: data) else {
                completion(nil)
                return
            }
            self?.ramCache.setObject(image, forKey: fileName as NSString, cost: data.count)
            let cachedImage = createCachedImage(image)
            DispatchQueue.main.async {
                completion(cachedImage)
            }
        }
    }

    func store(_ imageAndData: ImageAndData, url: URL) throws {
        let fileName = url.imageIdentifier
        ramCache.setObject(imageAndData.image, forKey: fileName as NSString, cost: imageAndData.imageData.count)
        let fileUrl = imageFolder.appendingPathComponent(fileName)
        try imageAndData.imageData.write(to: fileUrl)
    }

    func cleanup(targetSize: UInt64) throws {
        // Get all files with their attributes
        let contents = try fileManager.contentsOfDirectory(
            at: imageFolder, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])
        var files: [(url: URL, date: Date, size: UInt64)] = []

        var totalSize: UInt64 = 0

        // Collect file information
        for fileUrl in contents {
            let attrs = try fileManager.attributesOfItem(atPath: fileUrl.path)
            guard let size = attrs[.size] as? UInt64, let date = attrs[.modificationDate] as? Date else { continue }
            files.append((fileUrl, date, size))
            totalSize += size
        }

        // Sort by modification date (oldest first)
        files.sort { $0.date < $1.date }

        // Delete files until we reach target size
        for file in files {
            guard totalSize > targetSize else { break }
            try fileManager.removeItem(at: file.url)
            totalSize -= file.size
        }
    }

    private func getCroppedImageIfNeeded(_ image: UIImage, croppingRatio: Double?, url: URL) -> UIImage {
        guard let croppingRatio, croppingRatio > 0 else { return image }
        let croppedImageCacheId = "\(url.imageIdentifier)-\(croppingRatio)" as NSString
        // look in ram first
        if let image = ramCache.object(forKey: croppedImageCacheId) {
            return image
        }

        let originalSize = image.size
        let originalRatio = originalSize.width / originalSize.height

        // If the aspect ratio is already close enough, no need to crop
        if abs(originalRatio - croppingRatio) < 0.01 {
            return image
        }

        var cropRect = CGRect.zero

        if originalRatio < croppingRatio {
            // Image is too tall, crop vertically
            let newHeight = originalSize.width / CGFloat(croppingRatio)
            let originY = (originalSize.height - newHeight) / 2.0
            cropRect = CGRect(x: 0, y: originY, width: originalSize.width, height: newHeight)
        } else {
            // do not crop the image horizontally
            return image
        }

        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            return image
        }

        let croppedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        ramCache.setObject(croppedImage, forKey: croppedImageCacheId)
        return croppedImage
    }
}

extension URL {
    var imageIdentifier: String {
        return lastPathComponent
    }
}
