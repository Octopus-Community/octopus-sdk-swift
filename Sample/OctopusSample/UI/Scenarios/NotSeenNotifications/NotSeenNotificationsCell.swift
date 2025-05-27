//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// Scenario that shows how to get the number of Octopus internal notifications that are not seen yet.
struct NotSeenNotificationsCell: View {
    let showFullScreen: (@escaping () -> any View) -> Void

    var body: some View {
        NavigationLink(destination: NotSeenNotificationsView(showFullScreen: showFullScreen)) {
            VStack(alignment: .leading) {
                Text("Notification Badge")
                Text("To increase user engagement, let your users know that they have not seen internal notifications")
                    .font(.caption)
            }
        }
    }
}


