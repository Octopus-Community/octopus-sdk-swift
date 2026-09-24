//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

/// A text that can be ellipsized
struct EllipsizableText: Equatable {
    /// the full text
    let fullText: String
    /// The ellipsized text. Nil if no ellipse
    private let _ellipsizedText: String?

    /// The ellipsized text (fallback to full text if `isEllipsized` is false).
    var ellipsizedText: String { _ellipsizedText ?? fullText }

    /// Whether the text is ellipsized
    var isEllipsized: Bool { _ellipsizedText != nil }

    init?(text: String?, maxLength: Int = 200, maxLines: Int = 4) {
        guard let text = text?.nilIfEmpty else { return nil }
        self.init(text: text, maxLength: maxLength, maxLines: maxLines)
    }

    init(text: String, maxLength: Int = 200, maxLines: Int = 4) {
        self.fullText = text

        // Delegate to `TextTruncation`, the single definition of the truncation rule.
        let truncated = TextTruncation(maxLength: maxLength, maxLines: maxLines).truncate(text)
        _ellipsizedText = truncated.isTruncated ? truncated.text : nil
    }

    func getText(ellipsized: Bool) -> String {
        return ellipsized ? ellipsizedText : fullText
    }
}
