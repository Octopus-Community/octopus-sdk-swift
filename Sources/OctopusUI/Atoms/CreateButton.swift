//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

struct CreateButton: View {
    enum Kind {
        case post

        fileprivate var text: LocalizedStringKey {
            switch self {
            case .post: return "Post.List.OpenCreatePost"
            }
        }
    }

    @Environment(\.octopusTheme) private var theme
    /// Fixed 24×24 icon (design system), scaled with Dynamic Type.
    @Compat.ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 24
    let kind: Kind
    /// When `true`, the button collapses to an icon-only round FAB.
    let isReduced: Bool
    let actionTapped: () -> Void

    init(kind: Kind, isReduced: Bool = false, actionTapped: @escaping () -> Void) {
        self.kind = kind
        self.isReduced = isReduced
        self.actionTapped = actionTapped
    }

    var body: some View {
        Button(action: actionTapped) {
            HStack(spacing: isReduced ? 0 : 8) {
                IconImage(theme.assets.icons.content.post.creation.open, size: iconSize)
                    .accessibilityHidden(true)
                if !isReduced {
                    Text(kind.text, bundle: .module)
                        .fixedSize()
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .font(theme.fonts.body2.weight(.medium))
            .padding(16)
            .foregroundColor(theme.colors.onPrimary)
            .background(Capsule().fill(theme.colors.primary))
            .clipShape(Capsule())
            .contentShape(Capsule())
        }
        .accessibilityLabelInBundle(kind.text)
        // Value-driven animation so the extend/reduce always animates, even when the write-site
        // transaction (withAnimation in the scroll detector) doesn't reliably reach this deep
        // view during a fast fling.
        .animation(.easeInOut(duration: 0.3), value: isReduced)
    }
}

#Preview {
    VStack(spacing: 16) {
        CreateButton(kind: .post, isReduced: false, actionTapped: {})
        CreateButton(kind: .post, isReduced: true, actionTapped: {})
    }
}
