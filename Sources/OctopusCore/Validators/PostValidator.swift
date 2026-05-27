//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import UIKit

public extension Validators {
    enum Post {
        public enum TextError: Error {
            case empty
            case tooShort
            case tooLong
        }

        public static let minTextLength = 10
        public static let maxTextLength = 5000

        public static var minSize: CGFloat { Picture.minSize }
        public static var maxRatio: CGFloat { Picture.maxRatio }
        public static var maxRatioStr: String { Picture.maxRatioStr }

        public static func validate(picture: UIImage) -> Picture.ValidationResult {
            return Picture.validate(picture)
        }

        public static func validate(attachment: WritablePost.Attachment?) -> Bool {
            switch attachment {
            case .image:
                return true
            case let .poll(poll):
                return Poll.validate(poll)
            case .none:
                return true
            }
        }

        public static func validate(text: String, attachment: WritablePost.Attachment?,
                                    ignoreTooShort: Bool = false) -> Result<Void, TextError> {
            guard !text.isEmpty else { return .failure(.empty) }
            if !ignoreTooShort {
                switch attachment {
                case .poll: break
                default:
                    guard text.count >= minTextLength else { return .failure(.tooShort) }
                }
            }
            guard text.count <= maxTextLength else { return .failure(.tooLong) }
            return .success(Void())
        }

        public static func validate(post: WritablePost) -> Bool {
            return validate(text: post.text, attachment: post.attachment).isSuccess &&
                validate(attachment: post.attachment) &&
                !post.parentId.isEmpty
        }
    }
}
