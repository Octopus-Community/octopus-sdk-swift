//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import OctopusCore

/// Standalone translation-toggle block in the post card (the design's translation block).
///
/// Rendered only when the post's text or one of its poll options has a translation available. Without a poll
/// it sits between the text and the media; with a poll it sits below the poll, before the CTA (see the display
/// order in `PostView`). Horizontally padded to match the rest of the card's content blocks.
struct PostTranslationToggleView: View {
    @Environment(\.octopusTheme) private var theme

    let contentId: String
    let originalLanguage: String?

    var body: some View {
        HStack {
            ToggleTextTranslationButton(
                contentId: contentId,
                originalLanguage: originalLanguage,
                contentKind: .post)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, theme.sizes.horizontalPadding)
    }
}

#Preview {
    PostTranslationToggleView(contentId: "p1", originalLanguage: "fr")
        .mockEnvironmentForPreviews()
}
