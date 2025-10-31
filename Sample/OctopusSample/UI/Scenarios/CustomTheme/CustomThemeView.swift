//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// A view that shows how to customize the theme.
struct CustomThemeView: View {
    @StateObjectCompat private var viewModel = OctopusAuthSDKViewModel()

    let showFullScreen: (@escaping () -> any View) -> Void

    @State private var titleAsLogo: Bool = true
    @State private var navBarWithColor: Bool = false

    /// Create a custom theme
    let appTheme = OctopusTheme(
        colors: .init(
            primarySet: OctopusTheme.Colors.ColorSet(
                main: .Scenarios.CustomTheme.Colors.primary,
                lowContrast: .Scenarios.CustomTheme.Colors.primaryLow,
                highContrast: .Scenarios.CustomTheme.Colors.primaryHigh)),
        fonts: .init(
            title1: Font.custom("Courier New", size: 26),
            title2: Font.custom("Courier New", size: 20),
            body1: Font.custom("Courier New", size: 17),
            body2: Font.custom("Courier New", size: 14),
            caption1: Font.custom("Courier New", size: 12),
            caption2: Font.custom("Courier New", size: 10),
            navBarItem: Font.custom("Courier New", size: 17)
        ),
        assets: .init(logo: UIImage(resource: .Scenarios.CustomTheme.appLogo)))



    var body: some View {
        VStack(spacing: 30) {
            Toggle(isOn: $titleAsLogo) {
                Text("Use logo on Octopus Home Screen nav bar")
            }
            Toggle(isOn: $navBarWithColor) {
                Text("Use primary color on Octopus Home Screen nav bar")
            }
            Spacer()
            Button("Open Octopus Home Screen as full screen modal") {
                // Display the SDK full screen but outside the navigation view (see Architecture.md for more info)
                showFullScreen {
                    OctopusUIView(
                        octopus: viewModel.octopus,
                        // customize the leading nav bar item of the main screen.
                        // Either pass `.logo` to display the logo you provided in the theme, or `.text` to display
                        // a text you provide.
                        navBarLeadingItem: titleAsLogo ? .logo : .text(.init(text: "Bake It")),
                        // pass true to use the primary color you provided in the theme on the nav bar of the main
                        // screen. Otherwise it will be the default nav bar color.
                        navBarPrimaryColor: navBarWithColor)
                    /// Pass the custom theme
                    .environment(\.octopusTheme, appTheme)
                }
            }
            Spacer()
        }
        .padding()
    }
}


