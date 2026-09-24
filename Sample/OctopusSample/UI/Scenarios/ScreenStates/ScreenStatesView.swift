//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// Scenario exercising the screen states (OCT-1617): force the SDK offline, then open the community
/// to observe the empty / error states, their Retry and the no-connection toast.
///
/// A simulator reports a connection whatever the host does, so the SDK never sees an outage there —
/// without this override those states are only reachable on a device in airplane mode, which is how
/// each of their defects was found rather than caught here.
struct ScreenStatesView: View {
    @StateObjectCompat private var viewModel = ScreenStatesViewModel()
    @State private var presentCommunity = false

    private var octopus: OctopusSDK { OctopusSDKProvider.instance.octopus }

    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Debug-only: override the connectivity the SDK sees, then open the community. " +
                     "Offline, every list reports rather than spinning, and a list that already has " +
                     "content keeps it and shows a toast instead.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button(action: { viewModel.goOffline() }) {
                    optionLabel("Act offline", systemImage: "wifi.slash")
                }
                .accessibilityId("qa-screenStates-offline")

                Button(action: { viewModel.goOnline() }) {
                    optionLabel("Act online", systemImage: "wifi")
                }
                .accessibilityId("qa-screenStates-online")

                Button(action: { viewModel.clearOverride() }) {
                    optionLabel("Follow the device", systemImage: "arrow.uturn.backward")
                }
                .accessibilityId("qa-screenStates-clear")
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))

            VStack(alignment: .leading, spacing: 4) {
                Text("SDK currently sees")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(viewModel.isOffline ? "No connection" : "A connection (or the device's own)")
                    .font(.footnote)
                Text("""
                Once offline — open with nothing cached: the state replaces the list, with a Retry. \
                Tap Retry: it passes through the loader, never through the empty state. A list that \
                already has content keeps it and reports through a toast.
                """)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))

            Button(action: { presentCommunity = true }) {
                HStack {
                    Image(systemName: "rectangle.stack.badge.plus")
                    Text("Open community")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor))
            }
            .accessibilityId("screenStates-openCommunity")

            Spacer()
        }
        .padding()
        .navigationBarTitle("Screen states", displayMode: .inline)
        .sheet(isPresented: $presentCommunity) {
            OctopusUIView(octopus: octopus)
        }
        .onDisappear {
            // Restore the device's own connectivity so the next scenario boots clean.
            viewModel.clearOverride()
        }
        .hostAppFooter()
    }

    private func optionLabel(_ title: String, systemImage: String) -> some View {
        HStack {
            Image(systemName: systemImage)
            Text(title)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor))
    }
}
