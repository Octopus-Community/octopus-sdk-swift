//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// The button that opens the group picker: a light pill holding the selected group's name (or the invitation to
/// choose one) and a chevron.
struct TopicSelectionButton: View {
    @Environment(\.octopusTheme) private var theme

    let selectedTopicName: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let selectedTopicName {
                    Text(selectedTopicName)
                } else {
                    Text("Post.Create.Topic.Selection.Button", bundle: .module)
                }
                IconImage(theme.assets.icons.content.post.creation.topicSelection)
                    .font(theme.fonts.caption1)
                    .foregroundColor(theme.colors.gray700)
            }
            .font(theme.fonts.body2)
            .foregroundColor(theme.colors.gray900)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .composerPillBackground()
            // The pill is shorter than 44pt: the tap area grows around it, the pill keeps its size.
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The entries that add a picture or a poll to the post: one capsule each, an icon and its label side by side.
/// They float over the bottom of the form, so the content scrolls under them.
struct ComposerActionBar: View {
    @Environment(\.octopusTheme) private var theme
    @Compat.ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 24

    let canAddPicture: Bool
    let canAddPoll: Bool
    let addPicture: () -> Void
    let addPoll: () -> Void

    var body: some View {
        // Stacked at the accessibility text sizes, where the two capsules no longer fit side by side.
        AdaptiveAccessibleStack(hStackSpacing: Dimensions.spacing, vStackAlignment: .leading,
                                vStackSpacing: Dimensions.spacing) {
            if canAddPicture {
                capsuleButton(theme.assets.icons.content.post.creation.addPicture,
                              label: "Content.Create.AddPicture", action: addPicture)
            }
            if canAddPoll {
                capsuleButton(theme.assets.icons.content.post.creation.addPoll,
                              label: "Content.Create.AddPoll", action: addPoll)
            }
        }
    }

    /// The visible label is what VoiceOver reads, so the icon is hidden from it.
    private func capsuleButton(_ icon: UIImage, label: LocalizedStringKey,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Dimensions.iconLabelSpacing) {
                IconImage(icon, size: iconSize)
                    .accessibilityHidden(true)
                Text(label, bundle: .module)
                    .lineLimit(1)
            }
            .font(theme.fonts.body2)
            .foregroundColor(theme.colors.gray700)
            .padding(.horizontal, Dimensions.horizontalPadding)
            .frame(minHeight: Dimensions.minHeight)
            .composerPillBackground(interactive: true)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    /// Measured on the composer design (one point per pixel of its 393pt-wide screens).
    private enum Dimensions {
        static let spacing: CGFloat = 8
        static let iconLabelSpacing: CGFloat = 8
        static let horizontalPadding: CGFloat = 16
        static let minHeight: CGFloat = 44
    }
}

private extension View {
    /// The background of the composer pills: Liquid Glass on iOS 26, a plain gray capsule below. An
    /// `interactive` glass reacts to the touch, for the pills that are buttons as a whole.
    func composerPillBackground(interactive: Bool = false) -> some View {
        modify {
#if compiler(>=6.2)
            if #available(iOS 26.0, *), GlassEffect.isAvailable {
                $0.glassEffect(interactive ? .regular.interactive() : .regular, in: Capsule())
            } else {
                $0.composerPillFallbackBackground()
            }
#else
            $0.composerPillFallbackBackground()
#endif
        }
    }

    private func composerPillFallbackBackground() -> some View {
        modifier(ComposerPillFallbackBackground())
    }
}

private struct ComposerPillFallbackBackground: ViewModifier {
    @Environment(\.octopusTheme) private var theme

    func body(content: Content) -> some View {
        content.background(Capsule().foregroundColor(theme.colors.gray200))
    }
}
