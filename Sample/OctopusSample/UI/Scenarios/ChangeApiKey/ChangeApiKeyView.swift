//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// A view that shows how to change the API key, if you want to switch communities
struct ChangeApiKeyView: View {
    let showFullScreen: (@escaping () -> any View) -> Void

    @StateObjectCompat private var viewModel = ChangeApiKeyViewModel()

    var body: some View {
        VStack {
            SDKConfigView(afterSaveAction: {
                viewModel.changeApiKey()
            })

            Spacer()

            Button(action: {
                // Display the SDK full screen but outside the navigation view (see Architecture.md for more info)
                showFullScreen {
                    OctopusUIView(octopus: viewModel.octopus)
                }
            }) {
                Text("Open Octopus Home Screen")
            }
        }
        .padding()
    }
}

extension NSNotification.Name {
    static let apiKeyChanged = NSNotification.Name("OctopusSDK.apiKeyChanged")
}
