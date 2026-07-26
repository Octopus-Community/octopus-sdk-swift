//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// Scenario that shows how the groups list renders client sections (section titles + separators).
struct GroupSectionsCell: View {
    var body: some View {
        NavigationLink(destination: GroupSectionsView()) {
            HStack(spacing: 12) {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                VStack(alignment: .leading) {
                    Text("Group Sections")
                    Text("A community can group its groups into named client sections. The SDK renders " +
                         "each section title and a separator above every block except the first.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
