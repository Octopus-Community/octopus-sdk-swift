//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import OctopusCore

/// Translation toggle block ("Voir la traduction" / "Voir l'original") inside a response card.
/// Padding matches the Figma's `Content Trads` block: `pt-[6px] pb-[10px] pl-[12px] pr-[8px]`.
/// Only leading/trailing are applied here — `ToggleTextTranslationButton` already has internal
/// `.padding(.top, 6).padding(.bottom, 10)` (its own hit-area extension, matching the Figma
/// vertical spec). Adding the same values on the outer container would double-count and visibly
/// inflate the block — same pattern as `ResponseActionBarView`.
struct ResponseTranslationToggleView: View {
    @Environment(\.octopusTheme) private var theme

    let contentId: String
    let originalLanguage: String?
    /// `.comment` for comments and `.reply` for replies — drives which tracking event the
    /// existing `ToggleTextTranslationButton` emits on tap.
    let contentKind: SdkEvent.ContentKind

    var body: some View {
        HStack {
            ToggleTextTranslationButton(
                contentId: contentId,
                originalLanguage: originalLanguage,
                contentKind: contentKind)
            Spacer(minLength: 0)
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
    }
}

#Preview {
    ResponseTranslationToggleView(
        contentId: "r1", originalLanguage: "fr", contentKind: .comment)
    .padding()
    .mockEnvironmentForPreviews()
}
