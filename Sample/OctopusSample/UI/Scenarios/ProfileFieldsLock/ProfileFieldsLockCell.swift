//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// Scenario that shows how the community per-field profile lock adapts the profile and edit screens.
struct ProfileFieldsLockCell: View {
    var body: some View {
        NavigationLink(destination: ProfileFieldsLockView()) {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                VStack(alignment: .leading) {
                    Text("Profile Field Lock")
                    Text("A community can mark each profile field (nickname / avatar / bio) editable, " +
                         "read-only or disabled. The SDK adapts the profile and edit screens accordingly.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
