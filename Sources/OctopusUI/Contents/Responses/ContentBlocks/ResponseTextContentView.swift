//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import OctopusCore

struct ResponseTextContentView: View {
    @Environment(\.octopusTheme) private var theme
    @EnvironmentObject private var translationStore: ContentTranslationPreferenceStore

    let contentId: String
    let text: EllipsizableTranslatedText

    private var displayTranslation: Bool {
        translationStore.displayTranslation(for: contentId)
    }

    var body: some View {
        RichText(text.getFullText(translated: displayTranslation), truncation: text.truncation)
            .font(theme.fonts.body2)
            .octopusBodyContentLineHeight()
            .foregroundColor(theme.colors.gray900)
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .padding(.bottom, 2)
    }
}

#Preview("Full") {
    ResponseTextContentView(
        contentId: "r1",
        text: EllipsizableTranslatedText(
            text: TranslatableText(originalText: "A comment with some text content.",
                                   originalLanguage: nil),
            ellipsize: false))
    .padding()
    .mockEnvironmentForPreviews()
}

#Preview("Ellipsized") {
    ResponseTextContentView(
        contentId: "r1",
        text: EllipsizableTranslatedText(
            text: TranslatableText(
                originalText: "This is a much longer sample comment body that exists purely to push " +
                    "past the two hundred character truncation threshold so the preview finally shows " +
                    "the See more suffix and a clipped link. " +
                    "https://example.com/a-really-long-article-slug-for-testing",
                originalLanguage: nil),
            ellipsize: true))
    .padding()
    .mockEnvironmentForPreviews()
}
