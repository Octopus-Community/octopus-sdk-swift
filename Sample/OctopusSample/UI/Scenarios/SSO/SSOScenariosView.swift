//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct SSOScenariosView: View {
    let showFullScreen: (@escaping () -> any View) -> Void

    var body: some View {
        VStack(alignment: .leading) {
            List {
                WithoutAppManagedFieldsCell(showFullScreen: showFullScreen)
                WithAllAppManagedFieldsCell(showFullScreen: showFullScreen)
                WithSomeAppManagedFieldsCell(showFullScreen: showFullScreen)
            }
            Text("In order to test these scenarios, your community should be configured to use SSO authentication.")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.red)
                .padding()
        }
        .listStyle(.plain)
        .navigationBarTitle(Text("SSO Scenarios"), displayMode: .inline)
    }
}
