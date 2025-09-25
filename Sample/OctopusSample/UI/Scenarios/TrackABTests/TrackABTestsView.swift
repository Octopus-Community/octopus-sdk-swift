//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// A view that shows how to inform the SDK when you're doing an A/B test and not all of your users can access the
/// community UI.
struct TrackABTestsView: View {
    let showFullScreen: (@escaping () -> any View) -> Void

    @StateObjectCompat private var viewModel = TrackABTestsViewModel()

    var body: some View {
        VStack {
            Text("The following switch simulates an A/B test.\nWhen off, the community is hidden to the user.")
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            Toggle(isOn: $viewModel.canAccessCommunity) {
                Text("Can access the community")
            }

            Spacer().frame(height: 100)

            Button(action: {
                // Display the SDK full screen but outside the navigation view (see Architecture.md for more info)
                showFullScreen {
                    if let octopus = viewModel.octopus {
                        OctopusUIView(octopus: octopus)
                    } else {
                        EmptyView()
                    }
                }
            }) {
                Text("Open Octopus Home Screen")
            }
            .disabled(!viewModel.canAccessCommunity)
            Spacer()
        }
        .padding()
        .onAppear {
            viewModel.createSDK()
        }
        .onDisappear {
            viewModel.resetSDK()
        }
    }
}


