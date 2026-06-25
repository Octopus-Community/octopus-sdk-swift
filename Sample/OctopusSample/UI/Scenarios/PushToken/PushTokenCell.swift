//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// Scenario that displays the APNs device token registered by this build, so it can be copied and used to
/// test push notifications (e.g. with a direct APNs/SNS push to this specific device).
struct PushTokenCell: View {
    var body: some View {
        NavigationLink(destination: PushTokenView()) {
            HStack(spacing: 12) {
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                VStack(alignment: .leading) {
                    Text("Push Device Token")
                    Text("Show and copy the APNs device token registered for this build")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
