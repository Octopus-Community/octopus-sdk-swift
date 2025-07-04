//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// Scenario that shows how to dynamically create posts linked to an object of your app (article, product, item...).
struct BridgeToClientObjectCell: View {
    let showFullScreen: (@escaping () -> any View) -> Void

    var body: some View {
        NavigationLink(destination: BridgeToClientObjectView(showFullScreen: showFullScreen)) {
            VStack(alignment: .leading) {
                Text("Bridge to Client Object")
                Text("Have a post directly linked to a specific object (article, product, item...) of your app")
                    .font(.caption)
            }
        }
    }
}


