//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// Scenario that shows how to inform the SDK when you're doing an A/B test and not all of your users can access the
/// community UI.
struct ABTestsCell: View {
    let showFullScreen: (@escaping () -> any View) -> Void

    var body: some View {
        NavigationLink(destination: ABTestsView(showFullScreen: showFullScreen)) {
            VStack(alignment: .leading) {
                Text("A/B Tests")
                Text("To improve the analytics data we provide, inform the SDK if the user cannot access the community UI (during A/B tests for example).")
                    .font(.caption)
            }
        }
    }
}


