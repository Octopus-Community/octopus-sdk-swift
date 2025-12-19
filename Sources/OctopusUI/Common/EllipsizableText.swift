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
        self.fullText = text
        
        // Display max `maxLength` chars and `maxLines` new lines.
        let ellipsizedText = text
            .prefix(maxLength)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .prefix(maxLines)
            .joined(separator: "\n")
        
        if ellipsizedText != text {
            _ellipsizedText = ellipsizedText
        } else {
            _ellipsizedText = nil
        }
    }

    func getText(ellipsized: Bool) -> String {
        return ellipsized ? ellipsizedText : fullText
    }
}
