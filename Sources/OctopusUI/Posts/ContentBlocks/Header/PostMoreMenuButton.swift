//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI

struct PostMoreMenuButton: View {
    @Environment(\.octopusTheme) private var theme

    let canBeDeleted: Bool
    let canBeModerated: Bool
    let canBeBlockedByUser: Bool
    let onDelete: () -> Void
    let onReport: () -> Void
    let onBlockAuthor: () -> Void
    /// iOS 13 fallback binding: the parent view owns the action sheet state.
    @Binding var iOS13ActionSheetIsPresented: Bool

    @Compat.ScaledMetric(relativeTo: .subheadline) private var iconSize: CGFloat = 24

    var body: some View {
        if #available(iOS 14.0, *) {
            Menu(content: {
                if canBeDeleted {
                    Button(action: onDelete) {
                        Label(
                            title: { Text("Post.Delete.Button", bundle: .module) },
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
            // bubbles up to the enclosing `PostView`'s card-tap handler — which opens the
            // detail screen every time the user wants the menu. An empty high-priority
            // `TapGesture` consumes the SwiftUI tap while UIKit's `UIMenuInteraction` still
            // opens the menu independently.
            .highPriorityGesture(TapGesture().onEnded {})
        } else {
            // iOS 13: a plain `Button` already blocks the parent's `.onTapGesture`.
            Button(action: { iOS13ActionSheetIsPresented = true }) {
                moreIcon
            }
            .buttonStyle(.plain)
        }
    }

    private var moreIcon: some View {
        Image(uiImage: theme.assets.icons.common.moreActions)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: max(iconSize, 24), height: max(iconSize, 24))
            .foregroundColor(theme.colors.gray500)
            // Visual inset: the icon sits `horizontalPadding` pt from the trailing edge of the hit
            // area, so the button can extend flush to the card edge while the glyph remains
            // visually padded.
            .padding(.trailing, theme.sizes.horizontalPadding)
            // Visual top offset matching the header rhythm (8pt card + 8pt header - 2pt to align to the center).
            // The hit area extends up to the card's top edge.
            .padding(.top, 14)
            .frame(minWidth: 44, minHeight: 44, alignment: .topTrailing)
            .accessibilityLabelInBundle("Accessibility.Common.More")
    }
}

#Preview("Both actions") {
    StatefulPreview(initial: false) { binding in
        PostMoreMenuButton(
            canBeDeleted: true,
            canBeModerated: true,
            canBeBlockedByUser: true,
            onDelete: {},
            onReport: {},
            onBlockAuthor: {},
            iOS13ActionSheetIsPresented: binding)
    }
}

#Preview("Only moderate") {
    StatefulPreview(initial: false) { binding in
        PostMoreMenuButton(
            canBeDeleted: false,
            canBeModerated: true,
            canBeBlockedByUser: false,
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
