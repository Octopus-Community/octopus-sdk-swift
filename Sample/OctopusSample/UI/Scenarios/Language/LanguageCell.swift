//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// Scenario that shows how to customize the language.
/// Some apps do not use the default way of handling the language which provide the system/app defined language by the
/// user. If you have a custom setting inside your app that does not set the system AppLanguage, you can call a function
/// of Octopus in order to customize the language used (so Octopus does not use the system language but yours instead).
struct LanguageCell: View {
    var body: some View {
        NavigationLink(destination: LanguageView()) {
            VStack(alignment: .leading) {
                Text("Override the language of the SDK")
                Text("Octopus SDK lets you override the language use in the UI.")
                    .font(.caption)
            }
        }
    }
}


