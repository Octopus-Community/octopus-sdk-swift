//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// Scenario that shows how to open the Octopus SDK on a sheet.
struct SheetCell: View {
    @State private var showModal = false

    var body: some View {
        VStack(alignment: .leading) {
            Text("Open on a sheet")
            Text("Open the Octopus SDK in a non full screen sheet")
                .font(.caption)
        }
        .onTapGesture {
            showModal = true
        }
        .sheet(isPresented: $showModal) {
            // Init of OctopusSDK should be done as soon as possible in your app (in your AppDelegate for example)
            // This is not what we do here because this sample showcases multiple way of initializing the SDK.
            let octopus = try! OctopusSDK(apiKey: APIKeys.octopusAuth)
            OctopusHomeScreen(octopus: octopus)
        }
    }
}
