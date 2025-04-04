//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// Scenario that shows how to pass a custom theme to the Octopus SDK.
struct CustomThemeCell: View {
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

    @State private var showModal = false

    var body: some View {
        VStack(alignment: .leading) {
            Text("Custom theme")
            Text("Customize the theme of the Octopus UI")
                .font(.caption)
        }
        .onTapGesture {
            showModal = true
        }
        .fullScreenCover(isPresented: $showModal) {
            // Init of OctopusSDK should be done as soon as possible in your app (in your AppDelegate for example)
            // This is not what we do here because this sample showcases multiple way of initializing the SDK.
            let octopus = try! OctopusSDK(apiKey: APIKeys.octopusAuth)
            OctopusHomeScreen(octopus: octopus)
                /// Pass the custom theme
                .environment(\.octopusTheme, appTheme)
        }
    }
}
