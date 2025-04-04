//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// Scenario that shows how configure Octopus SDK in SSO mode with all app managed fields.
/// This means that all `ConnectionMode.SSOConfiguration.ProfileField` are managed by your app (i.e. moderation if any
/// should be handled by you, unicity of the nickname too).
struct WithAllAppManagedFieldsCell: View {
    var body: some View {
        // Since this scenario is a bit complex, opens it in a new screen (`SSOWithAllAppManagedFieldsView`)
        NavigationLink(destination: SSOWithAllAppManagedFieldsView()) {
            VStack(alignment: .leading) {
                Text("With all App Managed Fields")
                Text("All profile fields are managed by your app. This means that your user profile is the one that  " +
                     "will be used in the community. It also means that Octopus Community won't moderate the content " +
                     "of the profile (nickname, bio, and picture profile). It also means that you have to ensure " +
                     "that the nickname is unique.\n\n")
                .font(.caption)
                +
                Text("In order to test this scenario:\n" +
                     "- your community should be configured to use SSO authentication\n" +
                     "- your community should be configured to have all fields as app managed\n" +
                     "- you must set your API key to OCTOPUS_SSO_ALL_MANAGED_FIELDS_API_KEY in secrets.xcconfig\n"
                )
                .font(.caption)
                .foregroundColor(.red)
            }
        }
    }
}
