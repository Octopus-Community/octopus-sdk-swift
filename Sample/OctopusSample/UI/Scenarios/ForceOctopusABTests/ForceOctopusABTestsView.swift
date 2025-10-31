//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// A view that shows how to force the user cohort during Octopus internal A/B Tests.
struct ForceOctopusABTestsView: View {
    let showFullScreen: (@escaping () -> any View) -> Void

    @StateObjectCompat private var viewModel = ForceOctopusABTestsViewModel()

    @State private var canAccessCommunity = false

    var body: some View {
        VStack {
            Text("The following switch will permanently override the internal cohort attribution for the current user.")
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            Toggle(isOn: $viewModel.hasCommunityAccess) {
                Text("Can access the community")
            }

            Button(action: { viewModel.overrideCommunityAccess(enabled: viewModel.hasCommunityAccess) }) {
                Text("Override cohort attribution")
                    .padding()
            }.background(
                RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor)
            )

            Spacer().frame(height: 100)

            Button(action: {
                // Display the SDK full screen but outside the navigation view (see Architecture.md for more info)
                showFullScreen {
                    OctopusUIView(octopus: viewModel.octopus)
                }
            }) {
                Text("Open Octopus Home Screen")
            }
            Spacer()
        }
        .padding()
        .modify {
            if #available(iOS 15.0, *) {
                $0.alert(
                    "Error",
                    isPresented: Binding(
                        get: { viewModel.error != nil },
                        set: { isActive in
                            if !isActive {
                                viewModel.error = nil
                            }
                        }
                    ),
                    presenting: viewModel.error,
                    actions: { _ in },
                    message: { error in
                        Text(error.localizedDescription)
                    })
            } else {
                $0
            }
        }
    }
}


