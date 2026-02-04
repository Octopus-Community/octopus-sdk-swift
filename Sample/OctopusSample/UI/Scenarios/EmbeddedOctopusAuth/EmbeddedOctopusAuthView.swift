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

    @State private var id = UUID()

    var body: some View {
        Group {
            // You can pass a `bottomSafeAreaInset` in order to add some safe area at the bottom of `OctopusHomeScreen`.
            OctopusUIView(octopus: viewModel.octopus, bottomSafeAreaInset: 10)
                .id(id) // to recreate the view when the API Key changes
                .onReceive(NotificationCenter.default.publisher(for: .apiKeyChanged)) { _ in
                    id = UUID()
                }
        }
    }
}


