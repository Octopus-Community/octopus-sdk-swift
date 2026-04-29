//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import OctopusCore

struct PostCatchPhraseView: View {
    @Environment(\.octopusTheme) private var theme
    @EnvironmentObject private var translationStore: ContentTranslationPreferenceStore

    private enum CatchPhrase {
        case translatable(contentId: String, text: TranslatableText)
        case localizedKey(LocalizedStringKey)
    }

    private let catchPhrase: CatchPhrase

    /// Renders a translatable catch-phrase (e.g. a bridge post's catch-phrase).
    init(contentId: String, catchPhrase: TranslatableText) {
        self.catchPhrase = .translatable(contentId: contentId, text: catchPhrase)
    }

    /// Renders a system-owned localized string key (e.g. the moderated-post main text).
    init(localizedKey: LocalizedStringKey) {
        self.catchPhrase = .localizedKey(localizedKey)
    }

    var body: some View {
        HStack {
            textView
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, theme.sizes.horizontalPadding)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var textView: some View {
        switch catchPhrase {
        case let .translatable(contentId, text):
            Text(text.getText(translated: translationStore.displayTranslation(for: contentId)))
                .font(theme.fonts.body2)
                .fontWeight(.semibold)
                .foregroundColor(theme.colors.gray900)
        case let .localizedKey(key):
            Text(key, bundle: .module)
                .font(theme.fonts.body2)
                .fontWeight(.semibold)
                .foregroundColor(theme.colors.gray900)
        }
    }
}

#Preview {
    PostCatchPhraseView(
        contentId: "p1",
        catchPhrase: TranslatableText(originalText: "Catch phrase", originalLanguage: "en"))
    .mockEnvironmentForPreviews()
}
