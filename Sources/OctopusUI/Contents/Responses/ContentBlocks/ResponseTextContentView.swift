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
        textView
            .font(theme.fonts.body2)
            .foregroundColor(theme.colors.gray900)
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .padding(.bottom, 2)
    }

    @ViewBuilder
    private var textView: some View {
        if text.getIsEllipsized(translated: displayTranslation) {
            Text(verbatim: "\(text.getText(translated: displayTranslation))... ") +
            Text("Common.ReadMore", bundle: .module)
                .fontWeight(.medium)
                .foregroundColor(theme.colors.gray500)
        } else {
            RichText(text.getText(translated: displayTranslation))
                .lineSpacing(4)
        }
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
