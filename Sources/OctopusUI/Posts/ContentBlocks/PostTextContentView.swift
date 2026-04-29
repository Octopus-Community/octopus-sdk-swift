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

    /// Renders user-generated text with ellipsization. The translation toggle (when applicable)
    /// is a separate block rendered by `PostTranslationToggleView`.
    init(contentId: String, text: EllipsizableTranslatedText) {
        self.content = .translatable(contentId: contentId, text: text)
    }

    /// Renders a system-owned localized string key (e.g. the moderated-post reasons line).
    /// No translation toggle or ellipsization.
    init(localizedKey: LocalizedStringKey) {
        self.content = .localizedKey(localizedKey)
    }

    var body: some View {
        textView
            .font(theme.fonts.body2)
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
            if text.getIsEllipsized(translated: displayTranslation) {
                Text(verbatim: "\(text.getText(translated: displayTranslation))... ") +
                Text("Common.ReadMore", bundle: .module)
                    .fontWeight(.medium)
                    .foregroundColor(theme.colors.gray500)
            } else {
                RichText(text.getText(translated: displayTranslation))
                    .lineSpacing(4)
            }
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
            text: TranslatableText(originalText: "Un texte",
                                   originalLanguage: "fr",
                                   translatedText: "A text"),
            ellipsize: true))
    .mockEnvironmentForPreviews()
}
