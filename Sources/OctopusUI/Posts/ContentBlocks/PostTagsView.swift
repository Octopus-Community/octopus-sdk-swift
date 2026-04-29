//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

struct PostTagsView: View {
    @Environment(\.octopusTheme) private var theme

    let tags: [PostTag]

    var body: some View {
        if tags.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    badge(for: tag)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, theme.sizes.horizontalPadding)
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func badge(for tag: PostTag) -> some View {
        switch tag {
        case .moderated:
            PostTagBadge(
                icon: theme.assets.icons.content.post.moderated,
                text: Text("Post.Status.Moderated", bundle: .module),
                foreground: theme.colors.error,
                background: theme.colors.errorLowContrast)
        }
    }
}

private struct PostTagBadge: View {
    @Environment(\.octopusTheme) private var theme

    let icon: UIImage
    let text: Text
    let foreground: Color
    let background: Color

    /// Scales with Dynamic Type in lockstep with the text font so the icon grows alongside the
    /// caption. The text drives the overall badge height via its own vertical padding; the icon
    /// fits within that height with no extra padding around it.
    @Compat.ScaledMetric(relativeTo: .caption2) private var iconSize: CGFloat = 16

    var body: some View {
        HStack(spacing: 0) {
            Image(uiImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSize, height: iconSize)
                .foregroundColor(foreground)
            text
                .font(theme.fonts.caption2)
                .fontWeight(.semibold)
                .foregroundColor(foreground)
                .padding(.vertical, 2)
        }
        .padding(.leading, 4)
        .padding(.trailing, 8)
        .background(Capsule().fill(background))
    }
}

#Preview("Moderated") {
    PostTagsView(tags: [.moderated])
}

#Preview("Empty") {
    PostTagsView(tags: [])
}
