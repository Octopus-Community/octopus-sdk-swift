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
        private let pollValidator: Validators.Poll

        public init(pictureValidator: Validators.Picture, pollValidator: Validators.Poll) {
            self.pictureValidator = pictureValidator
            self.pollValidator = pollValidator
        }

        public func validate(picture: UIImage) -> Picture.ValidationResult {
            return pictureValidator.validate(picture)
        }

        public func validate(attachment: WritablePost.Attachment?) -> Bool {
            switch attachment {
            case .image:
                // We can't check picture because we only have the data here
                return true
            case let .poll(poll):
                return pollValidator.validate(poll)
            case .none:
                return true
            }
        }

        public func validate(text: String) -> Bool {
            return !text.isEmpty && text.count <= maxTextLength
        }

        public func validate(post: WritablePost) -> Bool {
            // Note that we can't check picture because we only have the data here
            return validate(text: post.text) &&
                validate(attachment: post.attachment) &&
                !post.parentId.isEmpty
        }
    }
}
