//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

struct EllipsizableTranslatedText: Equatable {
    private let translatableText: TranslatableText
    private let textIsEllipsized: Bool
    private let translatedTextIsEllipsized: Bool

    var hasTranslation: Bool { translatableText.hasTranslation }
    var originalLanguage: String? { translatableText.originalLanguage }

    init?(text: TranslatableText?, ellipsize: Bool = true, maxLength: Int = 200, maxLines: Int = 4) {
        guard let text else { return nil }
        self.init(text: text, ellipsize: ellipsize, maxLength: maxLength, maxLines: maxLines)
    }

    init(text: TranslatableText, ellipsize: Bool = true, maxLength: Int = 200, maxLines: Int = 4) {
        guard ellipsize else {
            translatableText = text
            textIsEllipsized = false
            translatedTextIsEllipsized = false
            return
        }
        // Display max `maxLength` chars and `maxLines` new lines.
        let displayableText = text.originalText
            .prefix(maxLength)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .prefix(4)
            .joined(separator: "\n")

        let displayableTranslatedText = text.translatedText.map {
            String($0.prefix(200))
                .split(separator: "\n", omittingEmptySubsequences: false)
                .prefix(4)
                .joined(separator: "\n")
        }

        translatableText = TranslatableText(originalText: displayableText,
                                            originalLanguage: text.originalLanguage,
                                            translatedText: displayableTranslatedText)
        textIsEllipsized = text.originalText != displayableText
        translatedTextIsEllipsized = text.translatedText != displayableTranslatedText
    }

    func getText(translated: Bool) -> String {
        translatableText.getText(translated: translated)
    }

    func getIsEllipsized(translated: Bool) -> Bool {
        guard hasTranslation else { return textIsEllipsized }
        return translated ? translatedTextIsEllipsized : textIsEllipsized
    }
}
