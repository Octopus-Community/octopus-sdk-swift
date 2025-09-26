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
        /// Color for elements that represents an error
        public let errorLowContrast: Color = .Gen.Theme.alertLowContrast
        /// Color of links
        public let link: Color = .Gen.Theme.link
        /// Color of the like button when the content is liked
        public let like: Color = .Gen.Theme.danger200
        /// Background color of the screens that are placed above others
        public let hover: Color = .Gen.Theme.hover

        /// Constructor of colors
        /// - Parameters:
        ///   - primarySet: the primary color set. Nil if you want the default value to be used.
        ///   - onPrimary: the color of a content displayed over a view with the primary color.
        ///                Nil if you want the default value to be used.
        public init(
            primarySet: ColorSet? = nil,
            onPrimary: Color? = nil) {
                self.primary = primarySet?.main ?? .Gen.Theme.Primary.main
                self.primaryLowContrast = primarySet?.lowContrast ?? .Gen.Theme.Primary.lowContrast
                self.primaryHighContrast = primarySet?.highContrast ?? .Gen.Theme.Primary.highContrast
                self.onPrimary = onPrimary ?? .Gen.Theme.gray100
            }
    }

    /// Assets of the theme
    public struct Assets: Sendable {
        // Editable values
        /// Your logo. Default value is Octopus logo
        public let logo: UIImage
        let logoIsCustomized: Bool

        /// Constructor of assets
        /// - Parameter logo: the logo. Nil if you want the default value (Octopus logo) to be used.
        public init(logo: UIImage? = nil) {
            self.logo = logo ?? .Gen.Theme.logo
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

        /// Constructor of fonts
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
            title1: Font = Font.system(size: UIFontMetrics(forTextStyle: .title1).scaledValue(for: 26)),
            title2: Font = Font.system(size: UIFontMetrics(forTextStyle: .title2).scaledValue(for: 22)),
            body1: Font = Font.system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: 18)),
            body2: Font = Font.system(size: UIFontMetrics(forTextStyle: .body).scaledValue(for: 16)),
            caption1: Font = Font.system(size: UIFontMetrics(forTextStyle: .caption1).scaledValue(for: 14)),
            caption2: Font = Font.system(size: UIFontMetrics(forTextStyle: .caption2).scaledValue(for: 12)),
            navBarItem: Font = .body
        ) {
            self.title1 = title1
            self.title2 = title2
            self.body1 = body1
            self.body2 = body2
            self.caption1 = caption1
            self.caption2 = caption2
            self.navBarItem = navBarItem
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
}
