//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

struct ReactionInteractionView: View {
    @Environment(\.octopusTheme) private var theme

    let defaultImage: UIImage
    let reaction: ReactionKind?

    @State private var animate = false

    @Compat.ScaledMetric(relativeTo: .caption1) private var reactionImageSize: CGFloat = 24

    private var normalFont: Font { theme.fonts.caption1 }

    private var isReacted: Bool { reaction != nil }

    private var textColor: Color {
        isReacted ? theme.colors.gray900 : theme.colors.gray700
    }

    var body: some View {
        HStack(spacing: 4) {
            Group {
                if let reaction {
                    Image(uiImage: theme.assets.icons.content.reaction[reaction])
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(uiImage: defaultImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(textColor)
                }
            }
            .frame(width: reactionImageSize, height: reactionImageSize)
            .scaleEffect(animate ? 1.4 : 1.0)
            .opacity(animate ? 0.9 : 1.0)
            .animation(
                .spring(response: 0.2, dampingFraction: 0.3),
                value: animate)

            Text((reaction ?? .heart).labelKey, bundle: .module)
                .font(normalFont)
                .fontWeight(.medium)
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
}
