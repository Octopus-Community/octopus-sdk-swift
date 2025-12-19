//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import UIKit
import OctopusDependencyInjection

public extension Validators {
    class Post {
        public enum TextError: Error {
            case empty
            case tooShort
            case tooLong
        }

        public let minTextLength = 10
        public let maxTextLength = 5000

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

        public func validate(text: String, attachment: WritablePost.Attachment?,
                             ignoreTooShort: Bool = false) -> Result<Void, TextError> {
            guard !text.isEmpty else { return .failure(.empty) }
            if !ignoreTooShort {
                switch attachment {
                case .poll: break // do not force min text length when a poll is attached
                default:
                    guard text.count >= minTextLength else { return .failure(.tooShort) }
                }
            }
            guard text.count <= maxTextLength else { return .failure(.tooLong) }
            return .success(Void())
        }

        public func validate(post: WritablePost) -> Bool {
            // Note that we can't check picture because we only have the data here
            return validate(text: post.text, attachment: post.attachment).isSuccess &&
                validate(attachment: post.attachment) &&
                !post.parentId.isEmpty
        }
    }
}

