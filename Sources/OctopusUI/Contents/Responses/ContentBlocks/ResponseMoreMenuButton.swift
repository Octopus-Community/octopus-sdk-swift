//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

/// Response-specific more-menu button. Mirrors `PostMoreMenuButton` but with the response-card
/// paddings (10pt trailing, 10pt top-inside) so the visual icon matches the Figma comment-header
/// geometry while the hit area still extends flush to the card's top and trailing edges.
struct ResponseMoreMenuButton: View {
    @Environment(\.octopusTheme) private var theme

    /// Drives the localized delete-menu label — `Comment.Delete.Button` for a comment,
    /// `Reply.Delete.Button` for a reply. Hardcoding "Post.Delete.Button" would surface the
    /// wrong copy in a comment/reply more-menu.
    let kind: ResponseKind
    let canBeDeleted: Bool
    let canBeModerated: Bool
    let canBeBlockedByUser: Bool
    let onDelete: () -> Void
    let onReport: () -> Void
    let onBlockAuthor: () -> Void
    /// iOS 13 fallback binding — the parent view owns the action-sheet state.
    @Binding var iOS13ActionSheetIsPresented: Bool

    @Compat.ScaledMetric(relativeTo: .subheadline) private var iconSize: CGFloat = 24

    var body: some View {
        if #available(iOS 14.0, *) {
            Menu(content: {
                if canBeDeleted {
                    Button(action: onDelete) {
                        Label(
                            title: { Text(kind.deleteButtonKey, bundle: .module) },
                            icon: { Image(uiImage: theme.assets.icons.content.delete) })
                    }
                }
                if canBeModerated {
                    DestructiveMenuButton(action: onReport) {
                        Label(
                            title: { Text("Moderation.Content.Button", bundle: .module) },
                            icon: { Image(uiImage: theme.assets.icons.content.report) })
                    }
                }
                if canBeBlockedByUser {
                    DestructiveMenuButton(action: onBlockAuthor) {
                        Label(
                            title: { Text("Block.Profile.Button", bundle: .module) },
                            icon: { Image(uiImage: theme.assets.icons.profile.blockUser) })
                    }
                }
            }, label: {
                moreIcon
            })
            .buttonStyle(.plain)
            // Absorbs a tap before the parent's `.onTapGesture` fires. On iOS 17+ the `Menu`
            // blocks propagation on its own, but on iOS 16 and earlier a tap on the Menu
            // bubbles up to the enclosing `ResponseView`'s card-tap handler — which opens
            // the detail screen every time the user wants the menu. An empty high-priority
            // `TapGesture` consumes the SwiftUI tap while UIKit's `UIMenuInteraction` still
            // opens the menu independently.
            .highPriorityGesture(TapGesture().onEnded {})
        } else {
            // iOS 13: a plain `Button` already blocks the parent's `.onTapGesture`, so no
            // explicit high-priority gesture is needed here (adding one would intercept the
            // button's own action).
            Button(action: { iOS13ActionSheetIsPresented = true }) {
                moreIcon
            }
            .buttonStyle(.plain)
        }
    }

    private var moreIcon: some View {
        IconImage(theme.assets.icons.common.moreActions)
            .font(theme.fonts.body2) // same as AuthorAndDateHeaderView.authorView
            .foregroundColor(theme.colors.gray500)
            // 10pt trailing inset so the icon sits flush with the Figma comment header's right side.
            .padding(.trailing, 10)
            // 10pt top inset so the hit area extends flush with the card's top edge + 6 visual top padding
            .padding(.top, 16)
            // 4pt bottom inset matching the Figma header's `pb-[4px]`. Applied INSIDE the hit
            // frame (i.e. before the outer `.frame` below) so this 4pt strip is part of the
            // button's tap area — taps just below the visible icon still open the menu.
            .padding(.bottom, 4)
            // Only a minimum width here — deliberately no `minHeight: 44`: the comment header is
            // already short (Profil+Date is ~37pt tall) and forcing a 44pt tap target would push
            // the whole header taller than the Figma spec. The button's height matches its
            // content (10pt top inset + icon + 4pt bottom inset), relying on the header's own
            // height to give a reasonable vertical tap surface.
            .frame(minWidth: 44, alignment: .topTrailing)
            .accessibilityLabelInBundle("Accessibility.Common.More")
    }
}
