//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// Scenario that shows how to force the user cohort during Octopus internal A/B Tests.
struct ForceOctopusABTestsCell: View {
    let showFullScreen: (@escaping () -> any View) -> Void

    var body: some View {
        NavigationLink(destination: ForceOctopusABTestsView(showFullScreen: showFullScreen)) {
            VStack(alignment: .leading) {
                Text("Force Octopus A/B Tests Cohort")
                Text("On some communities, Octopus can handle A/B Tests to let the user access the community or not. " +
                     "In those cases, we still provide you an api to override the internal status of the user to force the user cohort during Octopus internal A/B Tests.")
                    .font(.caption)
            }
        }
    }
}


