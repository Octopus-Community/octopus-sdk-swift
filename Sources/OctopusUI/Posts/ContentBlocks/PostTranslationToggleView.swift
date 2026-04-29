//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import OctopusCore

/// Standalone translation-toggle block in the post card (the Figma's "Content Trads").
///
/// Sits between the text/attachment and the CTA, rendered only when the post's text has a
/// translation available. Horizontally padded to match the rest of the card's content blocks.
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
