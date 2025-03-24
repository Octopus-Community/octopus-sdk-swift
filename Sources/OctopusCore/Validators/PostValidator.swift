//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import UIKit
import OctopusDependencyInjection

public extension Validators {
    class Post {
        public enum TextResult {
            case valid
            case tooLong
        }

        public let maxTextLength = 3000

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
            return !text.isEmpty && text.count <= maxTextLength
        }

        public func validate(post: WritablePost) -> Bool {
            // Note that we can't check picture because we only have the data here
            return validate(text: post.text) && !post.parentId.isEmpty
        }
    }
}
