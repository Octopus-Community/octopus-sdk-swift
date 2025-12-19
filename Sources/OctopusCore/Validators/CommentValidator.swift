//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import UIKit
import OctopusDependencyInjection

public extension Validators {
    class Comment {
        public enum TextResult {
            case valid
            case tooLong
        }

        public let maxTextLength = 5000

        public var minSize: CGFloat { pictureValidator.minSize }
        public var maxRatio: CGFloat { pictureValidator.maxRatio }
        public var maxRatioStr: String { pictureValidator.maxRatioStr }

        private let pictureValidator: Validators.Picture

        public init(pictureValidator: Validators.Picture) {
            self.pictureValidator = pictureValidator
        }

        public func validate(picture: UIImage) -> Picture.ValidationResult {
            return pictureValidator.validate(picture)
        }

        public func validate(text: String) -> Bool {
            return text.count <= maxTextLength
        }

        public func validate(comment: WritableComment) -> Bool {
            // Note that we can't check picture because we only have the data here
            switch (comment.imageData, comment.text?.nilIfEmpty) {
            case let (_, .some(text)): return validate(text: text)
            case (.none, .none): return false
            case (_, .none): return true
            }
        }
    }
}
