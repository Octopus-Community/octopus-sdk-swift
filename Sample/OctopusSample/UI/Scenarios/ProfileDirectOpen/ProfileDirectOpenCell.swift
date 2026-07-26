//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// Scenario that shows how to open the Octopus profile screen directly: either the connected user's own
/// profile, or another user's profile resolved from the host app's own clientUserId.
struct ProfileDirectOpenCell: View {
    var body: some View {
        NavigationLink(destination: ProfileDirectOpenView()) {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                VStack(alignment: .leading) {
                    Text("Open Profile Directly")
                    Text("Open the Octopus profile screen for the connected user, or for another user " +
                         "by your own clientUserId")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
