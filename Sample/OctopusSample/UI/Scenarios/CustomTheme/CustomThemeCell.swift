//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// Scenario that shows how to pass a custom theme to the Octopus SDK.
struct CustomThemeCell: View {
    let showFullScreen: (@escaping () -> any View) -> Void

    var body: some View {
        NavigationLink(destination: CustomThemeView(showFullScreen: showFullScreen)) {
            HStack(spacing: 12) {
                Image(systemName: "paintbrush")
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                VStack(alignment: .leading) {
                    Text("Custom theme")
                    Text("Customize the theme of the Octopus UI")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
