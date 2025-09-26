//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// Scenario that shows how to inform the SDK when you're doing an A/B test and not all of your users can access the
/// community UI.
struct TrackABTestsCell: View {
    let showFullScreen: (@escaping () -> any View) -> Void

    var body: some View {
        NavigationLink(destination: TrackABTestsView(showFullScreen: showFullScreen)) {
            VStack(alignment: .leading) {
                Text("Track A/B Tests")
                Text("If you are managing an AB Test to enable/disable community access to your users, inform the SDK if the user cannot access the community UI to improve the analytics data we provide.")
                    .font(.caption)
            }
        }
    }
}


