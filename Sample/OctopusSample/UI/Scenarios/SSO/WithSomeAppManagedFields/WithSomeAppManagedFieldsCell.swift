//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// Scenario that shows how configure Octopus SDK in SSO mode with some app managed fields (but not all).
/// This means that only some `ConnectionMode.SSOConfiguration.ProfileField` are managed by Octopus, the others are
/// managed in your app (i.e. moderation if any should be handled by you, unicity of the nickname too).
struct WithSomeAppManagedFieldsCell: View {
    let showFullScreen: (@escaping () -> any View) -> Void

    var body: some View {
        // Since this scenario is a bit complex, opens it in a new screen (`SSOWithSomeAppManagedFieldsView`)
        NavigationLink(destination: SSOWithSomeAppManagedFieldsView()) {
            VStack(alignment: .leading) {
                Text("Some App Managed Fields")
                Text("Some profile fields are managed by your app. This means these fields are the ones " +
                     "that will be used in the community. It also means that Octopus Community won't moderate those  " +
                     "fields (nickname, bio, or picture profile). It also means that, if the nickname is part of " +
                     "these fields, you have to ensure that it is unique.\n\n")
                .font(.caption)
                +
                Text("In order to test this scenario:\n" +
                     "- your community should be configured to use SSO authentication\n" +
                     "- your community should be configured to have some app managed fields\n" +
                     "- you must set those fields in SSOWithSomeAppManagedFieldsViewModel\n" +
                     "- you must set your API key to OCTOPUS_SSO_SOME_MANAGED_FIELDS_API_KEY in secrets.xcconfig"
                )
                .font(.caption)
                .foregroundColor(.red)
            }
        }
    }
}
