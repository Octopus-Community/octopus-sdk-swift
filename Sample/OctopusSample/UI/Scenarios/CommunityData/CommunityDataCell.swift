//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// Scenario that reads a member's public Octopus community stats so the host can render them itself.
struct CommunityDataCell: View {
    var body: some View {
        NavigationLink(destination: CommunityDataView()) {
            HStack(spacing: 12) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                VStack(alignment: .leading) {
                    Text("Community Data")
                    Text("Read a member's public Octopus stats (message count, gamification level) by " +
                         "clientUserId or profileId, one shot or observed, so your own profile screen " +
                         "can surface them without any Octopus UI.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
