//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

enum OctopusBadgeStyle {
    enum Kind {
        case medium
        case small
    }

    enum Status {
        case on
        case off
        case warning
        case admin
    }
}

struct OctopusBadgeModifier: ViewModifier {
    @Environment(\.octopusTheme) private var theme
    let kind: OctopusBadgeStyle.Kind
    let status: OctopusBadgeStyle.Status

    init(_ kind: OctopusBadgeStyle.Kind, status: OctopusBadgeStyle.Status) {
        self.kind = kind
        self.status = status
    }

    func body(content: Content) -> some View {
        HStack(spacing: 2) {
            content
            if status == .admin {
                Image(systemName: "checkmark.circle")
            }
        }
        .font(font)
        .padding(.leading, leadingPadding)
        .padding(.trailing, trailingPadding)
        .padding(.vertical, verticalPadding)
        .foregroundColor(foregroundColor)
        .background(
            Capsule()
                .fill(backgroundColor)
        )
    }
}

/// Colors extension
fileprivate extension OctopusBadgeModifier {
    var backgroundColor: Color {
        switch status {
        case .on:
            theme.colors.primary
        case .off:
            theme.colors.primaryLowContrast
        case .warning:
            theme.colors.errorLowContrast
        case .admin:
            theme.colors.primary
        }
    }

    var foregroundColor: Color {
        switch status {
        case .on:
            theme.colors.onPrimary
        case .off:
            theme.colors.primary
        case .warning:
            theme.colors.error
        case .admin:
            theme.colors.onPrimary
        }
    }
}

/// Paddings extension
fileprivate extension OctopusBadgeModifier {
    var leadingPadding: CGFloat {
        horizontalDefaultPadding
    }

    var trailingPadding: CGFloat {
        switch kind {
        case .medium:
            return horizontalDefaultPadding
        case .small:
            return status != .admin ? horizontalDefaultPadding : 2
        }
    }

    var horizontalDefaultPadding: CGFloat {
        switch kind {
        case .medium:
            return 12
        case .small:
            return 8
        }
    }

    var verticalPadding: CGFloat {
        switch kind {
        case .medium:
            return 8
        case .small:
            return status != .admin ? 2 : 4
        }
    }
}

/// Fonts extension
fileprivate extension OctopusBadgeModifier {
    var font: Font {
        switch kind {
        case .medium:
            theme.fonts.body2.weight(.semibold)
        case .small:
            theme.fonts.caption1.weight(.medium)
        }
    }
}

extension View {
    func octopusBadgeStyle(
        _ kind: OctopusBadgeStyle.Kind, status: OctopusBadgeStyle.Status) -> some View {
        return modifier(OctopusBadgeModifier(kind, status: status))
    }
}
