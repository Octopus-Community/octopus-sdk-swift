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
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                if viewModel.notSeenNotificationsCount > 0 {
                    Text("\(viewModel.notSeenNotificationsCount) unseen notification\(viewModel.notSeenNotificationsCount == 1 ? "" : "s")")
                        .font(.headline)
                } else {
                    Text("No unseen notifications")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }

            Button(action: {
                showFullScreen {
                    OctopusUIView(octopus: viewModel.octopus)
                }
            }) {
                ZStack(alignment: .topTrailing) {
                    HStack {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                        Text("Open Octopus Home Screen")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor))
                    .foregroundColor(.white)

                    if viewModel.notSeenNotificationsCount > 0 {
                        Text(verbatim: "\(viewModel.notSeenNotificationsCount)")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.white)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 6)
                            .background(Capsule().fill(Color.red))
                            .offset(x: 8, y: -10)
                    }
                }
            }
            .padding(.horizontal)

            Spacer()
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
