//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// Scenario that shows how the host app can consume a member's `clientUserId` to render its own
/// profile screen instead of the SDK's native one (Unified Profile).
struct UnifiedProfileCell: View {
    var body: some View {
        NavigationLink(destination: UnifiedProfileView()) {
            HStack(spacing: 12) {
                Image(systemName: "person.text.rectangle")
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                VStack(alignment: .leading) {
                    Text("Unified Profile")
                    Text("When active, tapping a member's profile routes to the host app (with their " +
                         "clientUserId) instead of showing the SDK's native profile screen.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
