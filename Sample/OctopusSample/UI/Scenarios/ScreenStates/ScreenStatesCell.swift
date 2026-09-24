//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// Scenario that makes the SDK act as if the device were offline, to reach the screen states.
struct ScreenStatesCell: View {
    var body: some View {
        NavigationLink(destination: ScreenStatesView()) {
            HStack(spacing: 12) {
                Image(systemName: "wifi.slash")
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                VStack(alignment: .leading) {
                    Text("Screen states (offline)")
                    Text("Forces the SDK offline so the empty / error states, their Retry and the " +
                         "no-connection toast can be exercised in the simulator.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
