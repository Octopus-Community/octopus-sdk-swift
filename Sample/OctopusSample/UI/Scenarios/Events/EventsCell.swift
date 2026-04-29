//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// Scenario that shows the list of all events emitted by the SDK.
struct EventsCell: View {
    var body: some View {
        NavigationLink(destination: EventsView()) {
            HStack(spacing: 12) {
                Image(systemName: "list.bullet")
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                VStack(alignment: .leading) {
                    Text("Events")
                    Text("Octopus SDK publishes events to inform you about what the user is doing inside the community. You can use these events to feed your own analytics tool.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
