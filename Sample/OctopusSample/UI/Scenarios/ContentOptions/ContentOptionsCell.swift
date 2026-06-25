//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// Scenario that shows how the community content options hide the picture / poll creation affordances
/// per content type (post / comment / reply).
struct ContentOptionsCell: View {
    var body: some View {
        NavigationLink(destination: ContentOptionsView()) {
            HStack(spacing: 12) {
                Image(systemName: "photo.badge.plus")
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                VStack(alignment: .leading) {
                    Text("Content Options")
                    Text("A community can disable pictures (per post / comment / reply) and polls. " +
                         "The SDK hides the corresponding creation affordances.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
