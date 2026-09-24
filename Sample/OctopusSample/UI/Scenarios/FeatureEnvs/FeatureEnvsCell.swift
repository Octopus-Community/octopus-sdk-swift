//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// Scenario that lets an internal developer target a live backend feature environment.
struct FeatureEnvsCell: View {

    var body: some View {
        NavigationLink(destination: FeatureEnvsView()) {
            HStack(spacing: 12) {
                // "flask" would fit better but is SF Symbols 5 (iOS 17+), and the Sample targets iOS 13 —
                // it would render blank there. "hammer" ships with SF Symbols 1.
                Image(systemName: "hammer")
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                VStack(alignment: .leading) {
                    Text("Feature Environments")
                    Text("Point the sample at a live backend feature env (per ticket) instead of the default community.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
