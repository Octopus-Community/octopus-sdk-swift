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
        // Editable values
        /// Accent color
        public let accent: Color
        /// Color of the text displayed over a view with accent color
        public let textOnAccent: Color

        // Non editable values
        public let gray200: Color = Color.Theme.gray200
        public let gray400: Color = Color.Theme.gray400
        public let gray500: Color = Color.Theme.gray500
        public let gray600: Color = Color.Theme.gray600

        /// Color for disabled elements
        public let disabled: Color = Color.Theme.gray400
        /// Color for elements that represents an error
        public let error: Color = Color.Theme.danger200
        /// Color of links
        public let link: Color = Color.Theme.link
        /// Colors of the like button when the content is liked
        public let like: Color = Color.Theme.danger200

        /// Constructor of colors
        /// - Parameters:
        ///   - accent: the accent color. Nil if you want the default value to be used.
        ///   - textOnAccent: the color of the text displayed over a view with accent color.
        ///                   Nil if you want the default value to be used.
        public init(
            accent: Color? = nil,
            textOnAccent: Color? = nil) {
                self.accent = accent ?? Color.Theme.accent
                self.textOnAccent = textOnAccent ?? Color.Theme.gray100
            }
    }

    /// Assets of the theme
    public struct Assets: Sendable {
        // Editable values
        /// Your logo. Default value is Octopus logo
        public let logo: UIImage
        
        /// Constructor of assets
        /// - Parameter logo: the logo. Nil if you want the default value (Octopus logo) to be used.
        public init(logo: UIImage? = nil) {
            self.logo = logo ?? .Theme.logo
        }
    }

    /// Fonts of the theme
    public struct Fonts: Sendable {

        // Non editable values
        /// Title 1 font
        public let title1: Font = Font.system(size: UIFontMetrics.default.scaledValue(for: 26))
        /// Title 2 font
        public let title2: Font = Font.system(size: UIFontMetrics.default.scaledValue(for: 22))
        /// Body 1 font
        public let body1: Font = Font.system(size: UIFontMetrics.default.scaledValue(for: 18))
        /// Body 2 font
        public let body2: Font = Font.system(size: UIFontMetrics.default.scaledValue(for: 16))
        /// Caption 1 font
        public let caption1: Font = Font.system(size: UIFontMetrics.default.scaledValue(for: 14))
        /// Caption 2 font
        public let caption2: Font = Font.system(size: UIFontMetrics.default.scaledValue(for: 12))

        let navBarItem: Font = .body
        let backButton: Font = .body.weight(.semibold)
        
        /// Constructor of fonts
        public init() { }
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
