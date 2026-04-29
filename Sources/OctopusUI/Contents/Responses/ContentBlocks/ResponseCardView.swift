//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

/// Gray rounded container used by `ResponseView` to group the header, text, translation toggle,
/// and image blocks. Children own their internal paddings (including any bottom spacer — the card
/// does not add one).
///
/// The visible gray rounded rectangle is inset 6pt from the top of this view: the view's frame
/// (and therefore the frames of the interactive children at the top of the card, like the author
/// button and more-menu button) extends 6pt above the visible background. Those children already
/// bake their visual glyph offset inside their own tappable frames, so the top 6pt is a
/// transparent-but-tappable strip that extends their hit areas upward into the avatar column's
/// whitespace. `.mask` (rather than `.clipShape`) is used so that rendering clips to the visible
/// shape while hit testing keeps the full frames — the usual SwiftUI pattern for decoupling
/// visible geometry from tap geometry.
///
/// The 6pt value matches the Figma's `pt-[6px]` whitespace above the comment/reply.
struct ResponseCardView<Content: View>: View {
    @Environment(\.octopusTheme) private var theme

    @ViewBuilder let content: () -> Content

    /// 6pt vertical offset used both for the invisible tap-area strip above the gray background
    /// and for the `.mask` that clips overflowing children (e.g. the image at the bottom).
    private let topInvisibleInset: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.colors.gray200)
                .padding(.top, topInvisibleInset)
        )
        .mask(
            // The builder-based `.mask { ... }` overload is iOS 15+; the legacy `.mask(_:)`
            // form is available from iOS 13 and does exactly what we need here.
            RoundedRectangle(cornerRadius: 8)
                .padding(.top, topInvisibleInset)
        )
    }
}

#Preview {
    ResponseCardView {
        Text("Preview content")
            .padding()
    }
    .padding()
    .mockEnvironmentForPreviews()
}
