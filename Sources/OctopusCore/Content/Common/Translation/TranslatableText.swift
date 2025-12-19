//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation

/// A text that can be translated into the language of the device
/// The translated text might be nil if there is not translation for this text or if the original text is already
/// in the language of the device
public struct TranslatableText: Equatable, Sendable {
    public let originalText: String
    public let translatedText: String?
    public let originalLanguage: String?

    public var hasTranslation: Bool { translatedText != nil }

    public init?(originalText: String?, originalLanguage: String?, translatedText: String?) {
        guard let originalText = originalText?.nilIfEmpty else { return nil }

        self.init(originalText: originalText, originalLanguage: originalLanguage, translatedText: translatedText)
    }

    public init(originalText: String, originalLanguage: String?, translatedText: String? = nil) {
        self.originalText = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        self.originalLanguage = originalLanguage
        self.translatedText = translatedText?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    public func getText(translated: Bool) -> String {
        if translated {
            return translatedText ?? originalText
        } else {
            return originalText
        }
    }
}
