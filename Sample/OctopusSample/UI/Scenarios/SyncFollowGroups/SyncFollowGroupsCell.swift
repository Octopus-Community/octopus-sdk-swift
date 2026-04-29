//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// Scenario that demonstrates the batch sync-follow-groups API.
struct SyncFollowGroupsCell: View {
    var body: some View {
        NavigationLink(destination: SyncFollowGroupsView()) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                VStack(alignment: .leading) {
                    Text("Sync Follow Groups")
                    Text("Batch follow/unfollow groups with per-action timestamps.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
