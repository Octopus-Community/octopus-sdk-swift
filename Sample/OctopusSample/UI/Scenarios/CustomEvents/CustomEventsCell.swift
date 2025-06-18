//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// Scenario that shows how to send custom analytics events.
struct CustomEventsCell: View {
    var body: some View {
        NavigationLink(destination: CustomEventsView()) {
            VStack(alignment: .leading) {
                Text("Custom events")
                Text("Integrate some of your custom events to the analytics we provide to you.")
                    .font(.caption)
            }
        }
    }
}


