//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import SwiftUI

private struct ForceColorSchemeModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    let forceColorScheme: Bool
    let forcedColorScheme: ColorScheme

    var color: Color {
        switch forcedColorScheme {
        case .light: .white
        case .dark: .black
        @unknown default: .black
        }
    }

    func body(content: Content) -> some View {
        content
            .colorScheme(forceColorScheme ? forcedColorScheme : colorScheme)
            .modify {
                if #available(iOS 16.0, *) {
                    $0.toolbarBackground(forceColorScheme ? color : Color(UIColor.systemBackground),
                                         for: .navigationBar)
                } else { $0 }
            }
    }
}

extension View {
    /// Force the color scheme of a view
    /// - Parameters:
    ///   - colorScheme: the color scheme to apply
    ///   - condition: when the condition is true, the color scheme will be applied
    func forceColorScheme(_ colorScheme: ColorScheme, condition: Bool) -> some View {
        self.modifier(ForceColorSchemeModifier(forceColorScheme: condition, forcedColorScheme: colorScheme))
    }
}
