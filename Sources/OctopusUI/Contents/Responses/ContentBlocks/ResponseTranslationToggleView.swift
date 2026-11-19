//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import OctopusCore

/// Translation toggle block ("See translation" / "See original") inside a response card, between
/// the header and the text.
///
/// It adds no vertical padding of its own: `ToggleTextTranslationButton` is a 26pt row whose 44pt hit
/// area spills over the header and the text, so the caller gives it a `zIndex` above them. The
/// insets match the design spec's translation block, `pl-[9px] pr-[8px]`: the text
/// of the card starts at 12pt, and the icon box starts 3pt before it so that the glyph, which has
/// whitespace drawn around it, lines up with the text.
struct ResponseTranslationToggleView: View {
    @Environment(\.octopusTheme) private var theme

    let contentId: String
    let originalLanguage: String?
    /// `.comment` for comments and `.reply` for replies — drives which tracking event the
    /// existing `ToggleTextTranslationButton` emits on tap.
    let contentKind: SdkEvent.ContentKind

    var body: some View {
        HStack(spacing: 0) {
            ToggleTextTranslationButton(
                contentId: contentId,
                originalLanguage: originalLanguage,
                contentKind: contentKind,
                leadingInset: 9,
                trailingInset: 8)
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    ResponseTranslationToggleView(
        contentId: "r1", originalLanguage: "fr", contentKind: .comment)
    .padding()
    .mockEnvironmentForPreviews()
}
