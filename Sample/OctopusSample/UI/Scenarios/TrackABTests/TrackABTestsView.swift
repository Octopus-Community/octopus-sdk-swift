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
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("The following switch simulates an A/B test.\nWhen off, the community is hidden to the user.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Toggle(isOn: $viewModel.canAccessCommunity) {
                    Text("Can access the community")
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
            .disabled(!viewModel.canAccessCommunity)
            .opacity(viewModel.canAccessCommunity ? 1 : 0.4)
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
