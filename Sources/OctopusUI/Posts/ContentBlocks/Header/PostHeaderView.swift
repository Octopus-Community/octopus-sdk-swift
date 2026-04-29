//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import OctopusCore
import SwiftUI

struct PostHeaderView: View {
    @Environment(\.octopusTheme) private var theme

    let context: PostViewContext
    let author: Author
    let relativeDate: String
    let topic: String
    let displayGroupName: Bool
    let groupTap: (() -> Void)?
    let canBeDeleted: Bool
    let canBeModerated: Bool
    let canBeBlockedByUser: Bool

    let displayProfile: (String) -> Void
    let onDelete: () -> Void
    let onReport: () -> Void
    let onBlockAuthor: () -> Void
    @Binding var iOS13ActionSheetIsPresented: Bool

    @Compat.ScaledMetric(relativeTo: .title1) private var avatarSize: CGFloat = 40

    var avatarImageSize: CGFloat { max(avatarSize, 40) }
    var avatarButtonSize: CGFloat { max(avatarSize, 44) }

    /// Whether the in-header `⋯` more-actions menu should render. Suppressed in `.detail`
    /// context because `PostDetailView` already surfaces the same menu in its navigation-bar
    /// trailing item — showing it twice on the same screen would be redundant.
    private var showsMoreMenu: Bool {
        if case .detail = context { return false }
        return canBeDeleted || canBeModerated || canBeBlockedByUser
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            OpenProfileButton(author: author, displayProfile: displayProfile) {
                AuthorAvatarView(avatar: author.avatar)
                    .frame(width: avatarImageSize, height: avatarImageSize)
                    // Visual inset: the avatar sits 12pt below the hit-area top, matching the
                    // 8pt (card) + 8pt (header rhythm) offset the Figma defines. The hit area
                    // itself extends up to the card's top edge.
                    .padding(.top, 16)
            }
            .frame(width: avatarButtonSize, alignment: .leading)

            // 8px spacing when button has same size than image, otherwise substract the image padding inside the button
            Spacer().frame(width: min(8 - max(avatarButtonSize - avatarImageSize, 0), 8))

            VStack(alignment: .leading, spacing: 2) {
                AuthorAndDateHeaderView(
                    author: author,
                    relativeDate: relativeDate,
                    // Top padding pushed inside the author/date view so its own tappable areas
                    // (name, date) extend up to the card's top edge.
                    topPadding: 16,
                    displayProfile: displayProfile)
                if displayGroupName {
                    PostGroupLinkView(groupName: topic, onTap: groupTap)
                }
            }

            Spacer(minLength: 8)

            if showsMoreMenu {
                PostMoreMenuButton(
                    canBeDeleted: canBeDeleted,
                    canBeModerated: canBeModerated,
                    canBeBlockedByUser: canBeBlockedByUser,
                    onDelete: onDelete,
                    onReport: onReport,
                    onBlockAuthor: onBlockAuthor,
                    iOS13ActionSheetIsPresented: $iOS13ActionSheetIsPresented)
            }
        }
        .padding(.leading, theme.sizes.horizontalPadding)
        // When the more menu is shown, its hit area extends flush to the card edge; the visible
        // icon sits `horizontalPadding` pt inside via the button's internal trailing padding.
        // When the menu is absent, keep the standard trailing padding so content doesn't touch
        // the edge.
        .padding(.trailing, showsMoreMenu ? 0 : theme.sizes.horizontalPadding)
        // Bottom-only: the 16pt top space is baked into each interactive child's hit area so the
        // tappable zone extends up to the card's top edge.
        .padding(.bottom, 4)
    }
}

#Preview("Summary with menu") {
    StatefulPreview(initial: false) { binding in
        PostHeaderView(
            context: .summary(onCardTap: {}, onChildrenTap: {}, displayGroupName: true),
            author: Author(
                profile: MinimalProfile(
                    uuid: "1", nickname: "Antoine",
                    avatarUrl: URL(string: "https://randomuser.me/api/portraits/men/75.jpg")!,
                    gamificationLevel: 1),
                gamificationLevel: nil),
            relativeDate: "il y a 3 min.",
            topic: "Groupe",
            displayGroupName: true,
            groupTap: {},
            canBeDeleted: true,
            canBeModerated: true,
            canBeBlockedByUser: true,
            displayProfile: { _ in },
            onDelete: {},
            onReport: {},
            onBlockAuthor: {},
            iOS13ActionSheetIsPresented: binding)
    }
}

#Preview("Detail — menu hidden even though capabilities allow it") {
    // In `.detail` context `PostHeaderView` suppresses the in-header more menu — the
    // underlying `canBeDeleted` / `canBeModerated` flags are still true, but the menu icon
    // is rendered by `PostDetailView`'s navigation-bar trailing item instead.
    StatefulPreview(initial: false) { binding in
        PostHeaderView(
            context: .detail,
            author: Author(
                profile: MinimalProfile(
                    uuid: "1", nickname: "Antoine",
                    avatarUrl: URL(string: "https://randomuser.me/api/portraits/men/75.jpg")!,
                    gamificationLevel: 1),
                gamificationLevel: nil),
            relativeDate: "il y a 3 min.",
            topic: "Groupe",
            displayGroupName: true,
            groupTap: nil,
            canBeDeleted: true,
            canBeModerated: true,
            canBeBlockedByUser: false,
            displayProfile: { _ in },
            onDelete: {},
            onReport: {},
            onBlockAuthor: {},
            iOS13ActionSheetIsPresented: binding)
    }
}

private struct StatefulPreview<V: View>: View {
    @State private var value: Bool
    let content: (Binding<Bool>) -> V
    init(initial: Bool, @ViewBuilder content: @escaping (Binding<Bool>) -> V) {
        self._value = State(initialValue: initial)
        self.content = content
    }
    var body: some View { content($value) }
}
