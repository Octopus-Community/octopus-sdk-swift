//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

/// A translatable user-generated text, plus how to shorten it when it is displayed.
///
/// The text is kept whole: truncation is applied by `RichText` at render time, after the markdown
/// has been parsed, so that link detection always sees the entire text and a link cut by the
/// truncation still points at its complete URL.
struct EllipsizableTranslatedText: Equatable {
    private let translatableText: TranslatableText
    /// The truncation to apply when rendering, or `nil` to render the text in full.
    let truncation: TextTruncation?

    var hasTranslation: Bool { translatableText.hasTranslation }
    var originalLanguage: String? { translatableText.originalLanguage }

    init?(text: TranslatableText?, ellipsize: Bool = true) {
        guard let text else { return nil }
        self.init(text: text, ellipsize: ellipsize)
    }

    init(text: TranslatableText, ellipsize: Bool = true) {
        translatableText = text
        truncation = ellipsize ? TextTruncation() : nil
    }

    /// The whole text, untruncated. This is what gets handed to `RichText` along with `truncation`.
    func getFullText(translated: Bool) -> String {
        translatableText.getText(translated: translated)
    }

    /// A plain-string rendition of the displayed text, for consumers that cannot use the
    /// attributed one — today, VoiceOver labels.
    ///
    /// Note this truncates the markdown *source*, whereas the display truncates the *parsed*
    /// text (`RichText`). The two agree for plain-text bodies; for a body containing markdown,
    /// the syntax the parser strips still counts against the budget here, so this rendition can
    /// report a truncation the screen does not show, and, symmetrically, can hand back fewer
    /// visible characters than the screen displays, since part of its budget goes to markdown
    /// syntax the reader never sees. Parsing here too would double the markdown parses per feed
    /// cell per render, which is not worth it for a label. It also reads the markdown source
    /// verbatim, so link syntax and URLs are spoken as written.
    func getTruncatedText(translated: Bool) -> (text: String, isTruncated: Bool) {
        let text = getFullText(translated: translated)
        guard let truncation else { return (text, false) }
        return truncation.truncate(text)
    }
}
