//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// Scenario that shows how configure Octopus SDK in SSO mode: to use your users directly interact with the community
struct SSOCell: View {
    @ObservedObject var model: SampleModel

    var body: some View {
        // Since this scenario is a bit complex, opens it in a new screen (`SSOView`)
        NavigationLink(destination: SSOView(model: model)) {
            VStack(alignment: .leading) {
                Text("SSO Connection")
                Text("Use your login system to let your user interact with the community")
                    .font(.caption)
            }
        }
    }
}
