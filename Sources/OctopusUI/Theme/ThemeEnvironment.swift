//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

private struct ThemeEnvironmentKey: EnvironmentKey {
    /// Computed property in order to be recomputed when dynamic size changes
    ///
    /// - Note: the environment should be set in order to avoid re-creating the default env each time a view accesses
    /// the default value
    static var defaultValue: OctopusTheme { OctopusTheme() }
}

public extension EnvironmentValues {
    var octopusTheme: OctopusTheme {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

extension View {
    /// Sets the theme of the environment on the views below, with its default fonts sized for the current text
    /// size, and sizes them again when it changes.
    ///
    /// The entry screens apply it, so that a theme the host created once, and so with fonts sized for the text size
    /// of that moment, still follows a text size change. Setting the environment also avoids re-creating the default
    /// theme each time a view below accesses it.
    func environmentThemeSizedForTextSize() -> some View {
        modifier(ThemeSizedForTextSizeModifier())
    }
}

/// A modifier rather than code in the entry screens' body: its body only runs again when the theme or the text size
/// changes, not each time an entry screen's state changes, which would hand a new theme to every view below.
private struct ThemeSizedForTextSizeModifier: ViewModifier {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.sizeCategory) private var sizeCategory

    func body(content: Content) -> some View {
        content.environment(\.octopusTheme, theme.resized(for: UIContentSizeCategory(compat: sizeCategory)))
    }
}
