//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import UIKit

enum ImageResizer {
    private static let maxSizeAllowed: CGFloat = 4000

    static func resize(originalSize: CGSize) -> CGSize {
        // If both width and height are already less than or equal to maxSizeAllowed, return original size
        guard originalSize.width > maxSizeAllowed || originalSize.height > maxSizeAllowed else {
            return originalSize
        }

        // Calculate the scaling factor based on the largest side
        let scaleFactor: CGFloat
        if originalSize.width > originalSize.height {
            // Width is the largest side
            scaleFactor = maxSizeAllowed / originalSize.width
        } else {
            // Height is the largest side
            scaleFactor = maxSizeAllowed / originalSize.height
        }

        // Calculate new dimensions while maintaining aspect ratio
        let newWidth = originalSize.width * scaleFactor
        let newHeight = originalSize.height * scaleFactor

        return CGSize(width: newWidth, height: newHeight)
    }

    static func resizeIfNeeded(imageData: Data) -> Data {
        guard let image = UIImage(data: imageData) else {
            return imageData
        }

        let newSize = resize(originalSize: image.size)

        let rect = CGRect(origin: .zero, size: newSize)
        let renderer = UIGraphicsImageRenderer(bounds: rect, format: image.imageRendererFormat)
        let actionBlock: (UIGraphicsImageRendererContext) -> Void = { _ in
            image.draw(in: rect)
        }
        if image.imageRendererFormat.opaque {
            return renderer.jpegData(withCompressionQuality: 1.0, actions: actionBlock)
        } else {
            return renderer.pngData(actions: actionBlock)
        }
    }
}
