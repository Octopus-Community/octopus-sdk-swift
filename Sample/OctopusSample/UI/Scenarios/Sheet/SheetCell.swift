//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// Scenario that shows how to open the Octopus SDK on a sheet.
struct SheetCell: View {
    let showInSheet: (@escaping () -> any View) -> Void

    @StateObjectCompat private var viewModel = OctopusAuthSDKViewModel()

    var body: some View {
        VStack(alignment: .leading) {
            Text("Open on a sheet")
            Text("Open the Octopus SDK in a non full screen sheet")
                .font(.caption)
        }
        .onTapGesture {
            // Display the SDK in a sheet but outside the navigation view (see Architecture.md for more info)
            showInSheet {
                OctopusUIView(octopus: viewModel.octopus)
            }
        }
    }
}
