//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

enum OctopusBadgeStyle {
    enum Kind {
        case xs
        case small
        case medium
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
        content
            .font(font)
            .padding(.leading, leadingPadding)
            .padding(.trailing, trailingPadding)
            .padding(.vertical, verticalPadding)
            .foregroundColor(foregroundColor)
            .background(
                Capsule()
                    .modify {
                        if status == .admin {
                            $0.stroke(backgroundColor)
                        } else {
                            $0.fill(backgroundColor)
                        }
                    }

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
            theme.colors.gray300
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
            theme.colors.gray900
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
        case .xs:       horizontalDefaultPadding
        case .small:    horizontalDefaultPadding
        case .medium:   horizontalDefaultPadding
        }
    }

    var horizontalDefaultPadding: CGFloat {
        switch kind {
        case .xs:       8
        case .small:    8
        case .medium:   12
        }
    }

    var verticalPadding: CGFloat {
        switch kind {
        case .xs:       2
        case .small:    4
        case .medium:   8
        }
    }
}

/// Fonts extension
fileprivate extension OctopusBadgeModifier {
    var font: Font {
        switch kind {
        case .xs:
            theme.fonts.caption2.weight(.medium)
        case .small:
            theme.fonts.caption1.weight(.medium)
        case .medium:
            theme.fonts.body2.weight(.semibold)
        }
    }
}

extension View {
    func octopusBadgeStyle(
        _ kind: OctopusBadgeStyle.Kind, status: OctopusBadgeStyle.Status) -> some View {
        return modifier(OctopusBadgeModifier(kind, status: status))
    }
}
