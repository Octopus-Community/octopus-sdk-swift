//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import UIKit

public extension Validators {
    enum Reply {
        public enum TextResult {
            case valid
            case tooLong
        }

        public static let maxTextLength = 5000

        public static var minSize: CGFloat { Picture.minSize }
        public static var maxRatio: CGFloat { Picture.maxRatio }
        public static var maxRatioStr: String { Picture.maxRatioStr }

        public static func validate(picture: UIImage) -> Picture.ValidationResult {
            return Picture.validate(picture)
        }

        public static func validate(text: String) -> Bool {
            return text.count <= maxTextLength
        }

        public static func validate(reply: WritableReply) -> Bool {
            // Note that we can't check picture because we only have the data here
            switch (reply.imageData, reply.text?.nilIfEmpty) {
            case let (_, .some(text)): return validate(text: text)
            case (.none, .none): return false
            case (_, .none): return true
            }
        }
    }
}
