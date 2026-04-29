//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// A view that shows how to change the API key, if you want to switch communities
struct SwitchCommunityView: View {
    let showFullScreen: (@escaping () -> any View) -> Void

    @State private var error: Error?
    @State private var displayError = false
    @StateObjectCompat private var viewModel = SwitchCommunityViewModel()

    var body: some View {
        ZStack {
            VStack {
                SDKConfigView(afterSaveAction: {
                    viewModel.switchCommunity()
                })

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
            if #available(iOS 14.0, *), viewModel.isLoading {
                ProgressView()
            }
        }
        .padding()
        .onReceive(viewModel.$error) { error in
            guard let error else { return }
            self.error = error
            displayError = true
        }
        .alert(isPresented: $displayError) {
            Alert(title: Text(error?.localizedDescription ?? "Unknown"))
        }
    }
}

extension NSNotification.Name {
    static let apiKeyChanged = NSNotification.Name("OctopusSDK.apiKeyChanged")
}
