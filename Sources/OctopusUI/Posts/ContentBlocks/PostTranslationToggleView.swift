//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import OctopusCore

/// Standalone translation-toggle block in the post card (the design's translation block).
///
/// Rendered only when the post's text or one of its poll options has a translation available, right under the
/// header and before any content (see the display order in `PostView`), so that the member knows the content is
/// translated before reading it. The caller gives it a `zIndex` above the other blocks: its 44pt hit area spills
/// over them (see `ToggleTextTranslationButton`).
struct PostTranslationToggleView: View {
    @Environment(\.octopusTheme) private var theme

    let contentId: String
    let originalLanguage: String?

    /// The icon box starts 3pt before the card's text gutter: the glyph has whitespace drawn around it, and this
    /// lines it up with the text below.
    private let iconWhitespace: CGFloat = 3

    var body: some View {
        HStack(spacing: 0) {
            ToggleTextTranslationButton(
                contentId: contentId,
                originalLanguage: originalLanguage,
                contentKind: .post,
                leadingInset: theme.sizes.horizontalPadding - iconWhitespace,
                trailingInset: theme.sizes.horizontalPadding)
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 0) {
        PostTranslationToggleView(contentId: "p1", originalLanguage: "fr")
        PostTranslationToggleView(contentId: "p2", originalLanguage: nil)
    }
    .mockEnvironmentForPreviews()
}
