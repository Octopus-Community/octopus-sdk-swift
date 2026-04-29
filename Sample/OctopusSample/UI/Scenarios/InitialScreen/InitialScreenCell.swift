//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// Scenario that shows how to open a specific post or group directly.
struct InitialScreenCell: View {
    var body: some View {
        NavigationLink(destination: InitialScreenView()) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.up.right.square")
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                VStack(alignment: .leading) {
                    Text("Initial Screen")
                    Text("Open a specific post or group directly")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
