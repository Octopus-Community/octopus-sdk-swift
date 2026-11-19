//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

/// "See translation" / "See original" button shown under the author header of an automatically
/// translated content, before the content itself.
///
/// It takes 26pt in the layout (at the default text size) but is tappable over 44pt: the hit area
/// spills `hitAreaOverflow` above and below onto the neighbouring blocks without pushing them. The
/// caller must give it a `zIndex` above its siblings, otherwise the block drawn after it (the text)
/// gets the taps of the bottom strip. Horizontally, the hit area covers the icon, the label and the
/// trailing inset: the leading inset is outside the button, so it is neither part of the declared
/// hit area nor of the accessibility frame.
struct ToggleTextTranslationButton: View {
    @Environment(\.octopusTheme) private var theme
    @EnvironmentObject private var translationStore: ContentTranslationPreferenceStore
    @Environment(\.trackingApi) private var trackingApi
    let contentId: String
    let originalLanguage: String?
    let contentKind: SdkEvent.ContentKind
    /// Space before the icon, outside the hit area. The icon has whitespace drawn in it, so this is a
    /// little less than the text inset of the container for the glyph to line up with the text below.
    let leadingInset: CGFloat
    /// Space between the label and the trailing edge of the hit area.
    let trailingInset: CGFloat

    @Compat.ScaledMetric(relativeTo: .caption1) private var scaledIconSize: CGFloat = 20
    /// Grows with the text size but never shrinks below 20pt: the row, and with it the hit area, would
    /// otherwise fall under 44pt at the smallest text sizes.
    private var iconSize: CGFloat { max(scaledIconSize, 20) }

    /// Whitespace above and below the 20pt icon: makes the 26pt row of the design.
    private let rowVerticalPadding: CGFloat = 3
    /// Extension of the hit area above and below the row: 26 + 2 × 9 = 44pt, Apple's minimum tap
    /// target. Added inside the button and removed outside, so the layout keeps the 26pt row.
    private let hitAreaOverflow: CGFloat = 9

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                let newValue = translationStore.toggleDisplayTranslation(for: contentId)
                trackingApi.trackTranslationButtonHit(translationDisplayed: newValue)
                trackingApi.emit(event: .translationButtonClicked(.init(
                    contentId: contentId, viewTranslated: newValue, contentKind: contentKind)))
            }
        }) {
            HStack(spacing: 2) {
                Image(uiImage: theme.assets.icons.content.translation)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                    .accessibilityHidden(true)
                // Always on one line. When it does not fit (largest text sizes, long translations of the
                // label), the middle is cut so that the language at the end stays visible.
                Text(localizedKey, bundle: .module)
                    .font(theme.fonts.caption1)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .foregroundColor(theme.colors.gray500)
            .padding(.vertical, rowVerticalPadding)
            .padding(.trailing, trailingInset)
            .padding(.vertical, hitAreaOverflow)
            .contentShape(Rectangle())
        }
        .padding(.vertical, -hitAreaOverflow)
        .padding(.leading, leadingInset)
    }

    var localizedKey: LocalizedStringKey {
        let displayTranslation = translationStore.displayTranslation(for: contentId)
        guard displayTranslation else {
            return "Common.ViewTranslation"
        }

        if let originalLanguage {
            return "Common.ViewOriginal_language:\(originalLanguage)"
        } else {
            return "Common.ViewOriginal"
        }
    }
}
