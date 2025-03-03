//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// Scenario that shows how configure Octopus SDK in SSO mode without any app managed fields.
/// This means that all `ConnectionMode.SSOConfiguration.ProfileField` are managed by Octopus.
struct WithoutAppManagedFieldsCell: View {
    @ObservedObject var model: SampleModel

    var body: some View {
        // Since this scenario is a bit complex, opens it in a new screen (`SSOWithoutAppManagedFieldsView`)
        NavigationLink(destination: SSOWithoutAppManagedFieldsView(model: model)) {
            VStack(alignment: .leading) {
                Text("No App Managed Fields")
                Text("All profile fields are managed by Octopus Community. This means that the info you provide in " +
                     "the connectUser are only used as prefilled values when the user creates its community profile. " +
                     "After that, they are not synchronized between your app and the community profile.\n\n")
                .font(.caption)
                +
                Text("In order to test this, your community should be configured to have no app managed fields.")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
}
