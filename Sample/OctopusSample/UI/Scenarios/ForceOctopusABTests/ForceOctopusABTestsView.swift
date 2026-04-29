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
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("The following switch will permanently override the internal cohort attribution for the current user.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Toggle(isOn: $viewModel.hasCommunityAccess) {
                    Text("Can access the community")
                }
                Button(action: { viewModel.overrideCommunityAccess(enabled: viewModel.hasCommunityAccess) }) {
                    HStack {
                        Image(systemName: "checkmark.shield")
                        Text("Override cohort attribution")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor))
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))

            Spacer()

            Button(action: {
                showFullScreen {
                    OctopusUIView(octopus: viewModel.octopus)
                }
            }) {
                HStack {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                    Text("Open Octopus Home Screen")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor))
                .foregroundColor(.white)
            }
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
