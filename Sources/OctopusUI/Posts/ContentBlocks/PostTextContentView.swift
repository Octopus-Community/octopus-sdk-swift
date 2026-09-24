//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import OctopusCore

struct PostTextContentView: View {
    @Environment(\.octopusTheme) private var theme
    @EnvironmentObject private var translationStore: ContentTranslationPreferenceStore

    private enum Content {
        case translatable(contentId: String, text: EllipsizableTranslatedText)
        case localizedKey(LocalizedStringKey)
    }

    private let content: Content

    /// Renders user-generated text, honouring the truncation policy carried by `text`. The
    /// translation toggle (when applicable) is a separate block rendered by `PostTranslationToggleView`.
    init(contentId: String, text: EllipsizableTranslatedText) {
        self.content = .translatable(contentId: contentId, text: text)
    }

    /// Renders a system-owned localized string key (e.g. the moderated-post reasons line).
    /// No translation toggle or truncation.
    init(localizedKey: LocalizedStringKey) {
        self.content = .localizedKey(localizedKey)
    }

    var body: some View {
        textView
            .font(theme.fonts.body2)
            .octopusBodyContentLineHeight()
            .foregroundColor(theme.colors.gray900)
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, theme.sizes.horizontalPadding)
            .padding(.vertical, 4)
    }

    @ViewBuilder
    private var textView: some View {
        switch content {
        case let .translatable(contentId, text):
            let displayTranslation = translationStore.displayTranslation(for: contentId)
            RichText(text.getFullText(translated: displayTranslation), truncation: text.truncation)
        case let .localizedKey(key):
            Text(key, bundle: .module)
        }
    }
}

#Preview("Detail (full)") {
    PostTextContentView(
        contentId: "p1",
        text: EllipsizableTranslatedText(
            text: TranslatableText(originalText: "A longer multi-line text with some\nline breaks",
                                   originalLanguage: nil),
            ellipsize: false))
    .mockEnvironmentForPreviews()
}

#Preview("Summary ellipsized") {
    PostTextContentView(
        contentId: "p1",
        text: EllipsizableTranslatedText(
            text: TranslatableText(
                originalText: "Un texte",
                originalLanguage: "fr",
                translatedText: "This is a much longer sample body text that exists purely to push " +
                    "past the two hundred character truncation threshold so the preview finally shows " +
                    "the See more suffix and a clipped link. " +
                    "https://example.com/a-really-long-article-slug-for-testing"),
            ellipsize: true))
    .mockEnvironmentForPreviews()
}
