//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// Scenario that shows how to change the API key, if you want to switch communities
struct ChangeApiKeyCell: View {
    let showFullScreen: (@escaping () -> any View) -> Void

    var body: some View {
        NavigationLink(destination: ChangeApiKeyView(showFullScreen: showFullScreen)) {
            VStack(alignment: .leading) {
                Text("Change Community")
                Text("Sometimes, you need to change the API key. Although it is not something we recommend, it can be useful if you want to switch communities.")
                    .font(.caption)
            }
        }
    }
}


