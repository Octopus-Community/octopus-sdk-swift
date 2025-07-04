//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

struct OctopusButtonStyle: ButtonStyle {
    @Environment(\.octopusTheme) private var theme

    enum Kind {
        enum SubKind {
            case outline
            case main
            case secondary
        }
        case main
        case mid(SubKind)
        case small(SubKind)
    }

    let kind: Kind
    let hasLeadingIcon: Bool
    let hasTrailingIcon: Bool
    let enabled: Bool

    init(_ kind: Kind, enabled: Bool = true, hasLeadingIcon: Bool = false, hasTrailingIcon: Bool = false) {
        self.kind = kind
        self.enabled = enabled
        self.hasLeadingIcon = hasLeadingIcon
        self.hasTrailingIcon = hasTrailingIcon
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .padding(.leading, leadingPadding)
            .padding(.trailing, trailingPadding)
            .padding(.vertical, verticalPadding)
            .foregroundColor(foregroundColor)
            .background(background)
    }
}

/// Colors extension
fileprivate extension OctopusButtonStyle {
    @ViewBuilder
    var background: some View {
        switch kind {
        case .main, .mid(.main), .small(.main):
            Capsule()
                .fill(enabled ? theme.colors.primary : theme.colors.disabledBg)
        case .mid(.outline), .small(.outline):
            Capsule()
                .stroke(theme.colors.gray300, lineWidth: 1)
        case .mid(.secondary), .small(.secondary):
            Capsule()
                .fill(enabled ? theme.colors.gray300 : theme.colors.disabledBg)
        }
    }

    var foregroundColor: Color {
        switch kind {
        case .main, .mid(.main), .small(.main):
            enabled ? theme.colors.onPrimary : theme.colors.onDisabled
        case .mid(.outline), .small(.outline):
            enabled ? theme.colors.gray900 : theme.colors.onDisabled
        case .mid(.secondary), .small(.secondary):
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
            Text("Main Active")
            Spacer()
            Button(action: {}) {
                Text("Click me")
            }.buttonStyle(OctopusButtonStyle(.main))
        }

        HStack {
            Text("Main Active With icon")
            Spacer()
            Button(action: {}) {
                HStack {
                    Image(systemName: "checkmark")
                    Text("Click me")
                }
            }.buttonStyle(OctopusButtonStyle(.main, hasLeadingIcon: true))
        }

        HStack {
            Text("Main Disabled")
            Spacer()
            Button(action: {}) {
                Text("Click me")
            }.buttonStyle(OctopusButtonStyle(.main, enabled: false))
        }

        HStack {
            Text("Mid main Active")
            Spacer()
            Button(action: {}) {
                Text("Click me")
            }.buttonStyle(OctopusButtonStyle(.mid(.main)))
        }

        HStack {
            Text("Mid main Disabled")
            Spacer()
            Button(action: {}) {
                Text("Click me")
            }.buttonStyle(OctopusButtonStyle(.mid(.main), enabled: false))
        }

        HStack {
            Text("Mid outline Active")
            Spacer()
            Button(action: {}) {
                Text("Click me")
            }.buttonStyle(OctopusButtonStyle(.mid(.outline)))
        }

        HStack {
            Text("Mid outline Disabled")
            Spacer()
            Button(action: {}) {
                Text("Click me")
            }.buttonStyle(OctopusButtonStyle(.mid(.outline), enabled: false))
        }

        HStack {
            Text("Mid secondary Active")
            Spacer()
            Button(action: {}) {
                Text("Click me")
            }.buttonStyle(OctopusButtonStyle(.mid(.secondary)))
        }

        HStack {
            Text("Mid secondary with icon")
            Spacer()
            Button(action: {}) {
                HStack {
                    Text("Click me")
                    Image(systemName: "checkmark")
                }
            }.buttonStyle(OctopusButtonStyle(.mid(.secondary), hasTrailingIcon: true))
        }

        HStack {
            Text("Mid secondary Disabled")
            Spacer()
            Button(action: {}) {
                Text("Click me")
            }.buttonStyle(OctopusButtonStyle(.mid(.secondary), enabled: false))
        }

        HStack {
            Text("Small main Active")
            Spacer()
            Button(action: {}) {
                Text("Click me")
            }.buttonStyle(OctopusButtonStyle(.mid(.main)))
        }

        HStack {
            Text("Small main Disabled")
            Spacer()
            Button(action: {}) {
                Text("Click me")
            }.buttonStyle(OctopusButtonStyle(.small(.main), enabled: false))
        }

        HStack {
            Text("Small outline Active")
            Spacer()
            Button(action: {}) {
                Text("Click me")
            }.buttonStyle(OctopusButtonStyle(.small(.outline)))
        }

        HStack {
            Text("Small outline Disabled")
            Spacer()
            Button(action: {}) {
                Text("Click me")
            }.buttonStyle(OctopusButtonStyle(.small(.outline), enabled: false))
        }

        HStack {
            Text("Small secondary Active")
            Spacer()
            Button(action: {}) {
                Text("Click me")
            }.buttonStyle(OctopusButtonStyle(.small(.secondary)))
        }

        HStack {
            Text("Small secondary with icon")
            Spacer()
            Button(action: {}) {
                HStack {
                    Text("Click me")
                    Image(systemName: "checkmark")
                }
            }.buttonStyle(OctopusButtonStyle(.small(.secondary), hasTrailingIcon: true))
        }

        HStack {
            Text("Small secondary Disabled")
            Spacer()
            Button(action: {}) {
                Text("Click me")
            }.buttonStyle(OctopusButtonStyle(.small(.secondary), enabled: false))
        }
    }
    .padding()
}
