//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import UIKit

/// The sample app's design tokens, ported role for role from the Android sample's `SampleTokens.kt` /
/// `Theme.kt` (design system v1).
///
/// These roles describe the *host app* chrome only. The Octopus SDK screens keep their own theme, so the
/// sample palette deliberately stays distinct from the SDK default one: a tester can always tell which
/// side of the integration a pixel belongs to.
///
/// Native divergences, on purpose:
/// - Colours resolve per trait collection (`UIColor { traits in … }`) instead of a Compose `CompositionLocal`,
///   so the light/dark switch is the system one and follows a forced `preferredColorScheme` too.
/// - Typography maps each Android role onto the closest Dynamic Type text style rather than a fixed point
///   size: the role keeps its weight and hierarchy, and the size follows the user's text size setting.
/// - Android's `platformAndroid` green is not ported; the iOS platform badge uses the Apple glyph instead.
enum SampleTokens {

    // MARK: - Colours

    /// Colour roles. Each one is a light/dark pair from the Android palette.
    enum Colors {
        static let navy = dynamic(light: 0x0F1B2D, dark: 0x0F1B2D)
        static let accent = dynamic(light: 0x1D88FE, dark: 0x1D88FE)
        /// Accent used for text and icons on a surface: the raw accent is under 4.5:1 on white.
        static let accentText = dynamic(light: 0x095FBF, dark: 0x7FB8FF)
        static let accentTint = dynamic(light: 0xE8F2FF, dark: 0x1B3556)
        static let accentContainer = dynamic(light: 0xD4E6FF, dark: 0x2A5EA0)
        static let onAccentContainer = dynamic(light: 0x0A3D7A, dark: 0xE3EFFF)

        static let background = dynamic(light: 0xF5F7FA, dark: 0x070D17)
        static let surface = dynamic(light: 0xFFFFFF, dark: 0x18253B)
        static let surface2 = dynamic(light: 0xE4E8EE, dark: 0x22324C)
        static let surface3 = dynamic(light: 0xDAE0E8, dark: 0x2E405C)

        static let text = dynamic(light: 0x0F1B2D, dark: 0xF2F5F9)
        static let textSecondary = dynamic(light: 0x566170, dark: 0xA3B0C2)
        /// Dark hairline is white at 8 % opacity (`0x14FFFFFF` on Android).
        static let hairline = dynamic(light: 0xE4E7EC, dark: 0xFFFFFF, darkAlpha: 0x14 / 255.0)
        static let border = dynamic(light: 0xC2CAD5, dark: 0x4A5F80)
        static let outline = dynamic(light: 0x747E8C, dark: 0x8093AB)

        static let buttonBackground = dynamic(light: 0x0F1B2D, dark: 0x1570D9)
        static let buttonText = dynamic(light: 0xFFFFFF, dark: 0xFFFFFF)
        static let onNavy = dynamic(light: 0xFFFFFF, dark: 0xFFFFFF)

        static let danger = dynamic(light: 0xB03A4E, dark: 0xF0A0A8)
        static let onDanger = dynamic(light: 0xFFFFFF, dark: 0x0A121E)
        static let dangerTint = dynamic(light: 0xF8EDEF, dark: 0x3F2E43)

        static let success = dynamic(light: 0x30B653, dark: 0x30B653)
        static let onSuccess = dynamic(light: 0x0F1B2D, dark: 0x0B1421)
        static let successText = dynamic(light: 0x176830, dark: 0x8FE0A8)
        static let successTint = dynamic(light: 0xE3F5E8, dark: 0x14301F)

        static let warning = dynamic(light: 0xD6A54C, dark: 0xD6A54C)
        static let onWarning = dynamic(light: 0x0F1B2D, dark: 0x0B1421)
        static let warningText = dynamic(light: 0x7A5716, dark: 0xE2BD78)
        static let warningTint = dynamic(light: 0xF9F2E6, dark: 0x3A3222)

        static let codeBackground = dynamic(light: 0x0F1B2D, dark: 0x03060C)
        static let codeText = dynamic(light: 0xD7E3F2, dark: 0xD7E3F2)

        // Derived roles, same aliases as Android.
        static let controlOff = outline
        static let focus = accent
        static let guest = warning

        /// Card shadow: navy at 10 % in light, black at 40 % in dark. Paired with a 1 pt `hairline` border.
        static let cardShadow = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(sampleHex: 0x000000, alpha: 0x66 / 255.0)
                : UIColor(sampleHex: 0x0F1B2D, alpha: 0x1A / 255.0)
        })

        private static func dynamic(light: UInt32, dark: UInt32, darkAlpha: CGFloat = 1) -> Color {
            Color(UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(sampleHex: dark, alpha: darkAlpha)
                    : UIColor(sampleHex: light)
            })
        }
    }

    // MARK: - Spacing

    /// 4 pt spacing scale.
    enum Spacing {
        static let space1: CGFloat = 4
        static let space2: CGFloat = 8
        static let space3: CGFloat = 12
        static let space4: CGFloat = 16
        static let space5: CGFloat = 20
        static let space6: CGFloat = 24
        static let space8: CGFloat = 32
        static let space10: CGFloat = 40
        /// Horizontal screen gutter.
        static let gutter: CGFloat = 16
        /// Vertical gap between two groups of rows.
        static let groupGap: CGFloat = 24
    }

    // MARK: - Radii

    enum Radius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let extraLarge: CGFloat = 16
        static let fab: CGFloat = 32
        static let pill: CGFloat = 999
    }

    // MARK: - Sizes

    enum Size {
        /// Minimum touch target. Android's 48 dp is above Apple's 44 pt minimum, so it is kept as is.
        static let touchMin: CGFloat = 48
        static let buttonHeight: CGFloat = 48
        static let buttonHeightSmall: CGFloat = 36
        static let rowMin: CGFloat = 56
        static let scenarioRowMin: CGFloat = 64
        static let badgeHeight: CGFloat = 28
        static let chipHeight: CGFloat = 40
        static let icon: CGFloat = 24
        static let iconSmall: CGFloat = 20
        static let iconExtraSmall: CGFloat = 16
        static let avatarSmall: CGFloat = 32
        static let avatarLarge: CGFloat = 56
        static let stateDisc: CGFloat = 64
    }

    // MARK: - Typography

    /// Type roles. Android sizes are in parentheses; nothing goes below 12, so `caption2` is never used.
    enum Typography {
        /// Screen title (26/34, semibold).
        static let title1 = Font.title.weight(.semibold)
        /// Section title (22/28, semibold).
        static let title2 = Font.title2.weight(.semibold)
        /// Card title (18/24, semibold).
        static let headline = Font.title3.weight(.semibold)
        /// Running text (16/22).
        static let body = Font.body
        /// Emphasised running text (16/22, medium).
        static let bodyStrong = Font.body.weight(.medium)
        /// Secondary text (14/20).
        static let callout = Font.subheadline
        /// Small text (12/16, medium).
        static let caption = Font.caption.weight(.medium)
        /// Field and row labels (14/20, semibold).
        static let label = Font.subheadline.weight(.semibold)
        /// Badge text (12/16, semibold).
        static let badgeLabel = Font.caption.weight(.semibold)
        /// Button text (16/22, semibold).
        static let buttonLabel = Font.body.weight(.semibold)
        /// Code and identifiers (13/18).
        static let mono = Font.system(.footnote, design: .monospaced)
        /// Small code (12/16).
        static let monoSmall = Font.system(.caption, design: .monospaced)
    }
}

extension UIColor {
    /// Builds a colour from a `0xRRGGBB` literal.
    convenience init(sampleHex hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
    }
}
