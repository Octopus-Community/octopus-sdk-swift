//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// Scenario that shows how to switch community
struct SwitchCommunityCell: View {
    let showFullScreen: (@escaping () -> any View) -> Void

    var body: some View {
        NavigationLink(destination: SwitchCommunityView(showFullScreen: showFullScreen)) {
            VStack(alignment: .leading) {
                Text("Switch Community")
                Text("Sometimes, you need to change of community. Although it is not something we recommend, it can be useful for example when you have one community per country.")
                    .font(.caption)
            }
        }
    }
}


