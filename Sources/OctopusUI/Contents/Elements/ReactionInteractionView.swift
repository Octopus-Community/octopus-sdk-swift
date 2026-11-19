//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

struct ReactionInteractionView: View {
    /// What follows the reaction icon.
    enum Caption: Equatable {
        /// The name of the member's reaction, or "Like": the comment and reply footers.
        case reactionLabel
        /// The total of reactions on the content, hidden at 0: the post footer.
        case count(Int)
    }

    @Environment(\.octopusTheme) private var theme
    @Environment(\.locale) private var locale

    let defaultImage: UIImage
    let reaction: ReactionKind?
    var caption: Caption = .reactionLabel

    @State private var animate = false

    @Compat.ScaledMetric(relativeTo: .caption1) private var reactionImageSize: CGFloat = 24

    private var normalFont: Font { theme.fonts.caption1 }

    private var isReacted: Bool { reaction != nil }

    private var textColor: Color {
        isReacted ? theme.colors.gray900 : theme.colors.gray700
    }

    private var spacing: CGFloat {
        switch caption {
        case .reactionLabel: 4
        case .count: 6
        }
    }

    var body: some View {
        HStack(spacing: spacing) {
            Group {
                if let reaction {
                    Image(uiImage: theme.assets.icons.content.reaction[reaction])
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(uiImage: defaultImage)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(textColor)
                }
            }
            .frame(width: reactionImageSize, height: reactionImageSize)
            .scaleEffect(animate ? 1.4 : 1.0)
            .opacity(animate ? 0.9 : 1.0)
            .animation(
                .spring(response: 0.2, dampingFraction: 0.3),
                value: animate)

            captionView
                .font(normalFont.weight(.medium))
                .foregroundColor(textColor)
        }
        .onValueChanged(of: reaction) { _ in
            animate = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                animate = false
            }
        }
        .hapticFeedback(trigger: animate) { oldValue, newValue in
            guard oldValue != newValue, newValue else { return false }
            return true
        }
    }

    @ViewBuilder
    private var captionView: some View {
        switch caption {
        case .reactionLabel:
            Text((reaction ?? .heart).labelKey, bundle: .module)
        case let .count(count):
            if count > 0 {
                Text(String.formattedCount(count, locale: locale))
                    .modify {
                        if #available(iOS 16.0, *) {
                            $0.contentTransition(.numericText())
                        } else {
                            $0
                        }
                    }
                    .animation(.default, value: count)
            }
        }
    }
}
