//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

struct CommunityAccessDeniedView: View {
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.octopusTheme) private var theme

    @Compat.StateObject private var viewModel: CommunityAccessDeniedViewModel
    private let canClose: Bool

    init(octopus: OctopusSDK, canClose: Bool) {
        _viewModel = Compat.StateObject(wrappedValue: CommunityAccessDeniedViewModel(octopus: octopus))
        self.canClose = canClose
    }

    var body: some View {
        ContentView(accessDeniedMessage: viewModel.accessDeniedMessage)
            .modify {
                if canClose {
                    $0.navigationBarItems(
                        leading:
                            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                                Image(systemName: "xmark")
                                    .font(theme.fonts.navBarItem)
                            }
                    )
                } else {
                    $0
                }
            }
        .onReceive(viewModel.$dismiss) { shouldDismiss in
            guard shouldDismiss else { return }
            presentationMode.wrappedValue.dismiss()
        }
    }
}

private struct ContentView: View {
    @Environment(\.octopusTheme) private var theme

    let accessDeniedMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            if let accessDeniedMessage {
                Text(accessDeniedMessage)
                    .font(theme.fonts.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.colors.gray900)
                    .multilineTextAlignment(.center)
            } else {
                Text("Error.Unknown", bundle: .module)
                    .font(theme.fonts.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.colors.gray900)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            PoweredByOctopusView()
        }
        .padding(.horizontal, 24)
    }
}

