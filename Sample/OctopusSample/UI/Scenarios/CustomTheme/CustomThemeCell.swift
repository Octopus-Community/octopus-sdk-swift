//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// Scenario that shows how to pass a custom theme to the Octopus SDK.
struct CustomThemeCell: View {
    @ObservedObject var model: SampleModel

    /// Create a custom theme
    let appTheme = OctopusTheme(
        colors: .init(
            primarySet: OctopusTheme.Colors.ColorSet(
                main: .Scenarios.CustomTheme.Colors.primary,
                lowContrast: .Scenarios.CustomTheme.Colors.primaryLow,
                highContrast: .Scenarios.CustomTheme.Colors.primaryHigh)),
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
            OctopusHomeScreen(octopus: model.octopus)
                /// Pass the custom theme
                .environment(\.octopusTheme, appTheme)
        }
    }
}
