//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

struct OctopusButtonStyle: ButtonStyle {
    @Environment(\.octopusTheme) private var theme

    enum Kind {
        case main
        case mid
        case small
    }

    enum Style {
        case outline
        case main
        case secondary
    }

    let kind: Kind
    let style: Style
    let hasLeadingIcon: Bool
    let hasTrailingIcon: Bool
    let customBackgroundColor: Color?
    let enabled: Bool

    let externalAllPadding: CGFloat
    let externalVerticalPadding: CGFloat
    let externalHorizontalPadding: CGFloat
    let externalLeadingPadding: CGFloat
    let externalTrailingPadding: CGFloat
    let externalTopPadding: CGFloat
    let externalBottomPadding: CGFloat

    init(_ kind: Kind,
         style: Style = .main,
         backgroundColor: Color? = nil,
         enabled: Bool = true,
         hasLeadingIcon: Bool = false,
         hasTrailingIcon: Bool = false,
         externalAllPadding: CGFloat = 0,
         externalVerticalPadding: CGFloat = 0,
         externalHorizontalPadding: CGFloat = 0,
         externalLeadingPadding: CGFloat = 0,
         externalTrailingPadding: CGFloat = 0,
         externalTopPadding: CGFloat = 0,
         externalBottomPadding: CGFloat = 0
    ) {
        self.kind = kind
        self.style = style
        self.customBackgroundColor = backgroundColor
        self.enabled = enabled
        self.hasLeadingIcon = hasLeadingIcon
        self.hasTrailingIcon = hasTrailingIcon
        self.externalAllPadding = externalAllPadding
        self.externalVerticalPadding = externalVerticalPadding
        self.externalHorizontalPadding = externalHorizontalPadding
        self.externalLeadingPadding = externalLeadingPadding
        self.externalTrailingPadding = externalTrailingPadding
        self.externalTopPadding = externalTopPadding
        self.externalBottomPadding = externalBottomPadding
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .padding(.leading, leadingPadding)
            .padding(.trailing, trailingPadding)
            .padding(.vertical, verticalPadding)
            .foregroundColor(foregroundColor)
            .background(background)
            .modify { if externalAllPadding != 0 { $0.padding(externalAllPadding) } else { $0 } }
            .modify { if externalVerticalPadding != 0 { $0.padding(.vertical, externalVerticalPadding) } else { $0 } }
            .modify { if externalHorizontalPadding != 0 { $0.padding(.horizontal, externalHorizontalPadding) } else { $0 } }
            .modify { if externalLeadingPadding != 0 { $0.padding(.leading, externalLeadingPadding) } else { $0 } }
            .modify { if externalTrailingPadding != 0 { $0.padding(.trailing, externalTrailingPadding) } else { $0 } }
            .modify { if externalTopPadding != 0 { $0.padding(.top, externalTopPadding) } else { $0 } }
            .modify { if externalBottomPadding != 0 { $0.padding(.bottom, externalBottomPadding) } else { $0 } }
            .contentShape(Rectangle())
    }
}

/// Colors extension
fileprivate extension OctopusButtonStyle {
    @ViewBuilder
    var background: some View {
        switch style {
        case .main:
            Capsule()
                .fill(backgroundColor)
        case .outline:
            Capsule()
                .stroke(theme.colors.gray300, lineWidth: 1)
                .background(
                    Capsule().fill(backgroundColor)
                )
        case .secondary:
            Capsule()
                .fill(backgroundColor)
        }
    }

    var backgroundColor: Color {
        if enabled {
            if let customBackgroundColor {
                return customBackgroundColor
            } else {
                switch style {
                    case .main:
                    return theme.colors.primary
                case .outline:
                    return .white.opacity(0.0001)
                case .secondary:
                    return theme.colors.gray300
                }
            }
        } else {
            return theme.colors.disabledBg
        }
    }

    var foregroundColor: Color {
        switch style {
        case .main:
            enabled ? theme.colors.onPrimary : theme.colors.onDisabled
        case .outline:
            enabled ? theme.colors.gray900 : theme.colors.onDisabled
        case .secondary:
            enabled ? theme.colors.gray900 : theme.colors.onDisabled
        }
    }
}

/// Paddings extension
fileprivate extension OctopusButtonStyle {
    var leadingPadding: CGFloat {
        return hasLeadingIcon ? verticalPadding : horizontalDefaultPadding
    }

    var trailingPadding: CGFloat {
        return hasTrailingIcon ? verticalPadding : horizontalDefaultPadding
    }

    var horizontalDefaultPadding: CGFloat {
        switch kind {
        case .main:
            return 32
        case .mid, .small:
            return 12
        }
    }

    var verticalPadding: CGFloat {
        switch kind {
        case .main:
            return 16
        case .mid, .small:
            return 8
        }
    }
}

/// Fonts extension
fileprivate extension OctopusButtonStyle {
    var font: Font {
        switch kind {
        case .main:
            theme.fonts.body2.weight(.medium)
        case .mid:
            theme.fonts.body2.weight(.medium)
        case .small:
            theme.fonts.caption1.weight(.medium)
        }
    }
}

#Preview {
    VStack {
        HStack {
            Text(verbatim: "Main Active")
            Spacer()
            Button(action: {}) {
                Text(verbatim: "Click me")
            }.buttonStyle(OctopusButtonStyle(.main))
        }

        HStack {
            Text(verbatim: "Main Active With icon")
            Spacer()
            Button(action: {}) {
                HStack {
                    Image(systemName: "checkmark")
                    Text(verbatim: "Click me")
                }
            }.buttonStyle(OctopusButtonStyle(.main, hasLeadingIcon: true))
        }

        HStack {
            Text(verbatim: "Main Disabled")
            Spacer()
            Button(action: {}) {
                Text(verbatim: "Click me")
            }.buttonStyle(OctopusButtonStyle(.main, enabled: false))
        }

        HStack {
            Text(verbatim: "Main with outlined style Active")
            Spacer()
            Button(action: {}) {
                Text(verbatim: "Click me")
            }.buttonStyle(OctopusButtonStyle(.main, style: .outline))
        }

        HStack {
            Text(verbatim: "Mid main Active")
            Spacer()
            Button(action: {}) {
                Text(verbatim: "Click me")
            }.buttonStyle(OctopusButtonStyle(.mid))
        }

        HStack {
            Text(verbatim: "Mid main Disabled")
            Spacer()
            Button(action: {}) {
                Text(verbatim: "Click me")
            }.buttonStyle(OctopusButtonStyle(.mid, enabled: false))
        }

        HStack {
            Text(verbatim: "Mid outline Active")
            Spacer()
            Button(action: {}) {
                Text(verbatim: "Click me")
            }.buttonStyle(OctopusButtonStyle(.mid, style: .outline))
        }

        HStack {
            Text(verbatim: "Mid outline Disabled")
            Spacer()
            Button(action: {}) {
                Text(verbatim: "Click me")
            }.buttonStyle(OctopusButtonStyle(.mid, style: .outline, enabled: false))
        }

        HStack {
            Text(verbatim: "Mid secondary Active")
            Spacer()
            Button(action: {}) {
                Text(verbatim: "Click me")
            }.buttonStyle(OctopusButtonStyle(.mid, style: .secondary))
        }

        HStack {
            Text(verbatim: "Mid secondary with icon")
            Spacer()
            Button(action: {}) {
                HStack {
                    Text(verbatim: "Click me")
                    Image(systemName: "checkmark")
                }
            }.buttonStyle(OctopusButtonStyle(.mid, style: .secondary, hasTrailingIcon: true))
        }

        HStack {
            Text(verbatim: "Mid secondary Disabled")
            Spacer()
            Button(action: {}) {
                Text(verbatim: "Click me")
            }.buttonStyle(OctopusButtonStyle(.mid, style: .secondary, enabled: false))
        }

        HStack {
            Text(verbatim: "Small main Active")
            Spacer()
            Button(action: {}) {
                Text(verbatim: "Click me")
            }.buttonStyle(OctopusButtonStyle(.small))
        }

        HStack {
            Text(verbatim: "Small main Disabled")
            Spacer()
            Button(action: {}) {
                Text(verbatim: "Click me")
            }.buttonStyle(OctopusButtonStyle(.small, enabled: false))
        }

        HStack {
            Text(verbatim: "Small outline Active")
            Spacer()
            Button(action: {}) {
                Text(verbatim: "Click me")
            }.buttonStyle(OctopusButtonStyle(.small, style: .outline))
        }

        HStack {
            Text(verbatim: "Small outline Disabled")
            Spacer()
            Button(action: {}) {
                Text(verbatim: "Click me")
            }.buttonStyle(OctopusButtonStyle(.small, style: .outline, enabled: false))
        }

        HStack {
            Text(verbatim: "Small secondary Active")
            Spacer()
            Button(action: {}) {
                Text(verbatim: "Click me")
            }.buttonStyle(OctopusButtonStyle(.small, style: .secondary))
        }

        HStack {
            Text(verbatim: "Small secondary with icon")
            Spacer()
            Button(action: {}) {
                HStack {
                    Text(verbatim: "Click me")
                    Image(systemName: "checkmark")
                }
            }.buttonStyle(OctopusButtonStyle(.small, style: .secondary, hasTrailingIcon: true))
        }

        HStack {
            Text(verbatim: "Small secondary Disabled")
            Spacer()
            Button(action: {}) {
                Text(verbatim: "Click me")
            }.buttonStyle(OctopusButtonStyle(.small, style: .secondary, enabled: false))
        }
    }
    .padding()
}
