//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// A view that displays the list of events emitted by the SDK
struct EventsView: View {
    @StateObjectCompat private var viewModel = EventsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.events.indices, id: \.self) { index in
                    let event = viewModel.events[index]
                    VStack(spacing: 4) {
                        Text(event.eventName)
                            .bold()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(event.params, id: \.self) { param in
                            Text(param)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 16)
                        }
                    }
                    .multilineTextAlignment(.leading)
                    .padding()
                    Color.gray.opacity(0.5).frame(height: 1)
                }
            }
        }
    }
}


