//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// A view that displays the Octopus UI directly
struct EmbeddedOctopusAuthView: View {
    @StateObjectCompat private var viewModel = OctopusAuthSDKViewModel()

    var body: some View {
        Group {
            if let octopus = viewModel.octopus {
                // You can pass a `bottomSafeAreaInset` in order to add some safe area at the bottom of `OctopusHomeScreen`.
                OctopusHomeScreen(octopus: octopus, bottomSafeAreaInset: 10)
                    .id(UUID()) // add an changing id so that every time Octopus is re-created, the view is re-init
            } else {
                Color.red
            }
        }
        .onAppear {
            viewModel.createSDK()
        }
    }
}


