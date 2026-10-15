//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit

/// Theme used by all the OctopusUI views
public struct OctopusTheme: Sendable {
    /// Colors of the theme
    public struct Colors: Sendable {
        public struct ColorSet: Sendable {
            /// Main color
            public let main: Color
            /// Main color with a lower contrast
            public let lowContrast: Color
            /// Main color with a higher contrast
            public let highContrast: Color

            /// Constructor
            /// - Parameters:
            ///   - main: the main color
            ///   - lowContrast: the low contrast variant of the main color
            ///   - highContrast: the high contrast variant of the main color
            public init(
                main: Color,
                lowContrast: Color,
                highContrast: Color
            ) {
                self.main = main
                self.lowContrast = lowContrast
                self.highContrast = highContrast
            }
        }
        // Editable values
        /// Primary color
        public let primary: Color
        /// Primary color with a lower contrast
        public let primaryLowContrast: Color
        /// Primary color with a higher contrast
        public let primaryHighContrast: Color
        /// Color of the text displayed over a view with primary color
        public let onPrimary: Color
        /// Color of links (e.g. URLs displayed in posts and comments)
        public let link: Color
        /// Background color of the community screens. Default is the system background
        /// (white in light mode, near-black in dark mode). Pass a dynamic `Color(UIColor { ... })`
        /// if you need a custom color that adapts to light/dark mode.
        public let background: Color

        // Non editable values
        public let gray100: Color = .Gen.Theme.gray100
        public let gray200: Color = .Gen.Theme.gray200
        public let gray300: Color = .Gen.Theme.gray300
        public let gray500: Color = .Gen.Theme.gray500
        public let gray700: Color = .Gen.Theme.gray700
        public let gray800: Color = .Gen.Theme.gray800
        public let gray900: Color = .Gen.Theme.gray900

        /// Color for disabled elements
        public let disabled: Color = .Gen.Theme.gray500
        /// Color for the background of disabled elements
        public let disabledBg: Color = .Gen.Theme.gray200
        /// Color for the text of disabled elements
        public let onDisabled: Color = .Gen.Theme.gray500
        /// Color for elements that represents an error
        public let error: Color = .Gen.Theme.danger200
        /// Low contrast color for elements that represents an error
        public let errorLowContrast: Color = .Gen.Theme.alertLowContrast
        /// Color for elements that represents a success
        public let success: Color = .Gen.Theme.success
        /// Low contrast color for elements that represents a success
        public let successLowContrast: Color = .Gen.Theme.successLowContrast
        /// Color of the like button when the content is liked
        public let like: Color = .Gen.Theme.danger200
        /// Background color of the screens that are placed above others
        public let hover: Color = .Gen.Theme.hover

        /// Constructor of colors
        /// - Parameters:
        ///   - primarySet: the primary color set. Nil if you want the default value to be used.
        ///   - onPrimary: the color of a content displayed over a view with the primary color.
        ///                Nil if you want the default value to be used.
        ///   - link: the color of links (e.g. URLs displayed in posts and comments).
        ///           Nil if you want the default value to be used.
        ///   - background: the background color of the community screens. Nil if you want the default
        ///                 value (system background) to be used.
        public init(
            primarySet: ColorSet? = nil,
            onPrimary: Color? = nil,
            link: Color? = nil,
            background: Color? = nil) {
                self.primary = primarySet?.main ?? .Gen.Theme.Primary.main
                self.primaryLowContrast = primarySet?.lowContrast ?? .Gen.Theme.Primary.lowContrast
                self.primaryHighContrast = primarySet?.highContrast ?? .Gen.Theme.Primary.highContrast
                self.onPrimary = onPrimary ?? .Gen.Theme.gray100
                self.link = link ?? .Gen.Theme.link
                self.background = background ?? Color(.systemBackground)
            }
    }

    /// Assets of the theme
    public struct Assets: Sendable {
        // Editable values
        /// Your logo. Default value is Octopus logo
        public let logo: UIImage
        let logoIsCustomized: Bool

        public let icons: Icons

        /// Constructor of assets
        /// - Parameter logo: the logo. Nil if you want the default value (Octopus logo) to be used.
        public init(logo: UIImage? = nil, icons: Icons = .init()) {
            self.logo = logo ?? .Gen.Theme.logo
            self.icons = icons
            logoIsCustomized = logo != nil
        }
    }

    /// Fonts of the theme
    public struct Fonts: Sendable {
        // Editable values
        /// Title 1 font
        public let title1: Font
        /// Title 2 font
        public let title2: Font
        /// Body 1 font
        public let body1: Font
        /// Body 2 font
        public let body2: Font
        /// Caption 1 font
        public let caption1: Font
        /// Caption 2 font
        public let caption2: Font
        /// Font used for navigation bar items.
        public let navBarItem: Font

        /// The text styles still on their default font: the only ones `resized(for:)` sizes again, the fonts given
        /// by the host are kept as they are.
        let defaultStyles: Set<Style>

        /// Constructor of fonts
        ///
        /// The default fonts follow the Dynamic Type text size, even when it changes while the Octopus UI is
        /// displayed: there is no need to create the theme again.
        /// - Parameters:
        ///   - title1: the font for the title1 text style. Default value is scaled system font with base size of 26
        ///   - title2: the font for the title2 text style. Default value is scaled system font with base size of 22
        ///   - body1: the font for the body1 text style. Default value is scaled system font with base size of 18
        ///   - body2: the font for the body2 text style. Default value is scaled system font with base size of 16
        ///   - caption1: the font for the caption1 text style. Default value is scaled system font with base size of 14
        ///   - caption2: the font for the caption2 text style. Default value is scaled system font with base size of 12
        ///   - navBarItem: the font for the navigation bar items. Default value is system `.body` to match the default
        ///                 font used for navigation bar items
        public init(
            title1: Font = Font.system(size: UIFontMetrics(forTextStyle: .title1).scaledValue(for: 26))
                .weight(.regular),
            title2: Font = Font.system(size: UIFontMetrics(forTextStyle: .title2).scaledValue(for: 22))
                .weight(.regular),
            body1: Font = Font.system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: 18))
                .weight(.regular),
            body2: Font = Font.system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: 16))
                .weight(.regular),
            caption1: Font = Font.system(size: UIFontMetrics(forTextStyle: .caption1).scaledValue(for: 14))
                .weight(.regular),
            caption2: Font = Font.system(size: UIFontMetrics(forTextStyle: .caption2).scaledValue(for: 12))
                .weight(.regular),
            navBarItem: Font = .body
        ) {
            self.title1 = title1
            self.title2 = title2
            self.body1 = body1
            self.body2 = body2
            self.caption1 = caption1
            self.caption2 = caption2
            self.navBarItem = navBarItem
            // A font equal to the default one is the default one. The defaults carry a `.weight(.regular)` that a
            // host font has no reason to carry, so that a fixed `.system(size: 16)` given by the host never passes
            // for the default `body2`, which it would equal when the theme is created at the default text size.
            let fonts: [Style: Font] = [
                .title1: title1, .title2: title2, .body1: body1, .body2: body2,
                .caption1: caption1, .caption2: caption2,
            ]
            self.defaultStyles = Set(Style.allCases.filter { fonts[$0] == $0.defaultFont() })
        }

        private init(title1: Font, title2: Font, body1: Font, body2: Font, caption1: Font, caption2: Font,
                     navBarItem: Font, defaultStyles: Set<Style>) {
            self.title1 = title1
            self.title2 = title2
            self.body1 = body1
            self.body2 = body2
            self.caption1 = caption1
            self.caption2 = caption2
            self.navBarItem = navBarItem
            self.defaultStyles = defaultStyles
        }

        /// The same fonts, with the default ones sized for `sizeCategory`.
        ///
        /// A default font is a system font of a fixed size, computed for the text size in effect when the theme was
        /// created: without this, a theme kept by the host would never follow a text size change.
        func resized(for sizeCategory: UIContentSizeCategory) -> Fonts {
            let traits = UITraitCollection(preferredContentSizeCategory: sizeCategory)
            func font(_ style: Style, _ font: Font) -> Font {
                defaultStyles.contains(style) ? style.defaultFont(compatibleWith: traits) : font
            }
            return Fonts(
                title1: font(.title1, title1), title2: font(.title2, title2),
                body1: font(.body1, body1), body2: font(.body2, body2),
                caption1: font(.caption1, caption1), caption2: font(.caption2, caption2),
                navBarItem: navBarItem, defaultStyles: defaultStyles)
        }

        /// The text styles whose default font is a system font scaled with the text size. `navBarItem` is not one of
        /// them: its default, `.body`, already follows the text size on its own.
        enum Style: CaseIterable, Sendable {
            case title1, title2, body1, body2, caption1, caption2

            /// The default font of the style, sized for the text size of `traits`, or the app's one without traits.
            ///
            /// Without traits, it is the exact expression of the default values of `init`, so that a font left to
            /// its default compares equal to it. Keep the `.weight(.regular)` of both: it is what tells a default
            /// font from a system font of the same size given by the host.
            func defaultFont(compatibleWith traits: UITraitCollection? = nil) -> Font {
                let metrics = UIFontMetrics(forTextStyle: textStyle)
                guard let traits else { return Font.system(size: metrics.scaledValue(for: baseSize)).weight(.regular) }
                return Font.system(size: metrics.scaledValue(for: baseSize, compatibleWith: traits)).weight(.regular)
            }

            private var baseSize: CGFloat {
                switch self {
                case .title1: 26
                case .title2: 22
                case .body1: 18
                case .body2: 16
                case .caption1: 14
                case .caption2: 12
                }
            }

            private var textStyle: UIFont.TextStyle {
                switch self {
                case .title1: .title1
                case .title2: .title2
                case .body1, .body2: .body
                case .caption1: .caption1
                case .caption2: .caption2
                }
            }
        }
    }

    /// The colors of the theme
    public let colors: Colors
    /// The fonts of the theme
    public let fonts: Fonts
    /// The assets of the theme
    public let assets: Assets

    /// Constructor
    /// - Parameters:
    ///   - colors: the colors of the theme. Default value is default colors. See `OctopusTheme.Colors`.
    ///   - fonts: the fonts of the theme. Default value is default fonts. See `OctopusTheme.Fonts`.
    ///   - assets: the assets of the theme. Default value is default assets. See `OctopusTheme.Assets`.
    public init(
        colors: Colors = Colors(),
        fonts: Fonts = Fonts(),
        assets: Assets = Assets()) {
            self.colors = colors
            self.fonts = fonts
            self.assets = assets
        }

    /// The same theme, with its default fonts sized for `sizeCategory`. See `Fonts.resized(for:)`.
    func resized(for sizeCategory: UIContentSizeCategory) -> OctopusTheme {
        OctopusTheme(colors: colors, fonts: fonts.resized(for: sizeCategory), assets: assets)
    }
}
