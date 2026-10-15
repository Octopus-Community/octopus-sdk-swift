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

        public static func validate(poll: WritablePoll?) -> Bool {
            guard let poll else { return true }
            return Poll.validate(poll)
        }

        /// - Parameters:
        ///   - hasPoll: whether the post carries a poll, with or without an image. Such a post is exempt from
        ///     the minimum text length.
        ///   - hasImage: whether the post carries an image.
        ///   - textRequired: the community setting. When `false`, a post with an image may have no text: a blank
        ///     text (empty or whitespace only) is then valid. Any other text follows the usual length rules.
        public static func validate(text: String, hasPoll: Bool, hasImage: Bool = false, textRequired: Bool = true,
                                    ignoreTooShort: Bool = false) -> Result<Void, TextError> {
            if canOmitText(text, hasImage: hasImage, textRequired: textRequired) {
                return .success(Void())
            }
            guard !text.isEmpty else { return .failure(.empty) }
            if !ignoreTooShort && !hasPoll {
                guard text.count >= minTextLength else { return .failure(.tooShort) }
            }
            guard text.count <= maxTextLength else { return .failure(.tooLong) }
            return .success(Void())
        }

        /// The text to publish. When the post may omit its text (see
        /// `validate(text:hasPoll:hasImage:textRequired:ignoreTooShort:)`), a blank text is sent empty rather
        /// than as whitespace; otherwise the text is sent as typed.
        public static func publishableText(_ text: String, hasImage: Bool, textRequired: Bool) -> String {
            canOmitText(text, hasImage: hasImage, textRequired: textRequired) ? "" : text
        }

        /// - Parameter textRequired: the community setting, see
        ///   `validate(text:hasPoll:hasImage:textRequired:ignoreTooShort:)`.
        public static func validate(post: WritablePost, textRequired: Bool = true) -> Bool {
            return validate(text: post.text, hasPoll: post.poll != nil, hasImage: post.image != nil,
                            textRequired: textRequired).isSuccess &&
                validate(poll: post.poll) &&
                !post.parentId.isEmpty
        }

        /// Whether the post may go without its text: the community makes text optional, the post carries an
        /// image and the text is blank (empty or whitespace only).
        private static func canOmitText(_ text: String, hasImage: Bool, textRequired: Bool) -> Bool {
            !textRequired && hasImage && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}
