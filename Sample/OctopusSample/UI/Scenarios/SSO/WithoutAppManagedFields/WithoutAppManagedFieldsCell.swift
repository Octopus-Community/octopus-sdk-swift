//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// Scenario that shows how configure Octopus SDK in SSO mode without any app managed fields.
/// This means that all `ConnectionMode.SSOConfiguration.ProfileField` are managed by Octopus.
struct WithoutAppManagedFieldsCell: View {
    let showFullScreen: (@escaping () -> any View) -> Void
    
    var body: some View {
        // Since this scenario is a bit complex, opens it in a new screen (`SSOWithoutAppManagedFieldsView`)
        NavigationLink(destination: SSOWithoutAppManagedFieldsView()) {
            VStack(alignment: .leading) {
                Text("No App Managed Fields")
                Text("All profile fields are managed by Octopus Community. This means that the info you provide in " +
                     "the connectUser are only used as prefilled values when the user creates its community profile. " +
                     "After that, they are not synchronized between your app and the community profile.\n\n")
                .font(.caption)
                +
                Text("In order to test this scenario:\n" +
                     "- your community should be configured to use SSO authentication\n" +
                     "- your community should be configured to have no app managed fields\n" +
                     "- you must set your API key to OCTOPUS_SSO_NO_MANAGED_FIELDS_API_KEY in secrets.xcconfig"
                )
                .font(.caption)
                .foregroundColor(.red)
            }
        }
    }
}
