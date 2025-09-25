//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// A view that shows how to display a badge when there are not seen Octopus internal notifications.
/// There is also a function to call whenever you want to update that value (it will be fetched from the server).
struct NotSeenNotificationsView: View {
    let showFullScreen: (@escaping () -> any View) -> Void

    @StateObjectCompat private var viewModel = NotSeenNotificationsViewModel()

    var body: some View {
        VStack {
            ZStack(alignment: .topTrailing) {
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
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.2)))

                if viewModel.notSeenNotificationsCount > 0 {
                    Text(verbatim: "\(viewModel.notSeenNotificationsCount)")
                        .foregroundColor(.white)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                        .background(
                            Group {
                                if viewModel.notSeenNotificationsCount == 1 {
                                    Circle()
                                        .fill(Color.red)
                                } else {
                                    Capsule()
                                        .fill(Color.red)
                                }
                            }
                        )
                        .offset(x: 8, y: -12)
                }
            }
        }
        .navigationBarItems(trailing: Button(action: { viewModel.updateNotSeenNotificationsCount() }) {
            Image(systemName: "arrow.clockwise")
        })
        .onAppear {
            // update the count when the view is displayed
            viewModel.updateNotSeenNotificationsCount()
        }
    }
}


