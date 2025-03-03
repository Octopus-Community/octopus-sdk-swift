//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// Scenario that shows how to open the Octopus SDK on a sheet.
struct SheetCell: View {
    @ObservedObject var model: SampleModel

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
            OctopusHomeScreen(octopus: model.octopus)
        }
    }
}
