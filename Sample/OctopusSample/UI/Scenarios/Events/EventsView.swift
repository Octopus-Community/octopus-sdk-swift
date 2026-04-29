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
        Group {
            if viewModel.events.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("No events yet")
                        .foregroundColor(.secondary)
                    Text("Interact with the SDK to see events appear here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.events.indices, id: \.self) { index in
                            let event = viewModel.events[index]
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "bolt.fill")
                                    .foregroundColor(.accentColor)
                                    .font(.caption)
                                    .padding(.top, 2)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.eventName)
                                        .bold()
                                    ForEach(event.params, id: \.self) { param in
                                        Text(param)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                            if index < viewModel.events.count - 1 {
                                Divider().padding(.leading, 36)
                            }
                        }
                    }
                }
            }
        }
    }
}
