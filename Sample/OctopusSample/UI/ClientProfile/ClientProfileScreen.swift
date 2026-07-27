//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

/// Full-screen presented when the SDK invokes `onNavigateToProfileCallback`. This is the host
/// app's own "profile" stand-in for the tapped member: once a host app wires the Unified Profile
/// callback, the SDK never shows its native profile screens, so the host renders its own screen
/// using the `clientUserId` handed back by the callback (OCT-1374).
struct ClientProfileScreen: View {
    @Environment(\.presentationMode) private var presentationMode
    @StateObjectCompat private var viewModel: ClientProfileViewModel
    @State private var presentCommunityActivity = false

    init(clientUserId: String) {
        _viewModel = StateObjectCompat(wrappedValue: ClientProfileViewModel(clientUserId: clientUserId))
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Client user id")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(verbatim: viewModel.clientUserId)
                        .font(.system(.body, design: .monospaced))
                }
                Divider()
                communityDataPanel
                Spacer()
                Button(action: { presentCommunityActivity = true }) {
                    HStack {
                        Image(systemName: "text.bubble")
                        Text("See their Octopus posts")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor))
                    .foregroundColor(.white)
                }
                .accessibilityId("clientProfile-seePosts")
            }
            .padding()
            .navigationBarTitle("Host App Profile", displayMode: .inline)
            .navigationBarItems(
                trailing:
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark")
                    }
            )
            .sheet(isPresented: $presentCommunityActivity) {
                OctopusUIView(
                    octopus: OctopusSDKProvider.instance.octopus,
                    initialScreen: .activity(.init(clientUserId: viewModel.clientUserId))
                )
            }
            .onAppear {
                Task { await viewModel.fetchCommunityData() }
            }
            .hostAppFooter()
        }
    }

    @ViewBuilder
    private var communityDataPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Octopus community data")
                .font(.caption)
                .foregroundColor(.secondary)
            switch viewModel.state {
            case .loading:
                if #available(iOS 14.0, *) {
                    ProgressView()
                } else {
                    Text("Loading…")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            case let .loaded(communityData):
                communityDataContent(communityData)
            case let .error(message):
                Text("Error: \(message)")
                    .font(.footnote)
                    .foregroundColor(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
        .accessibilityId("clientProfile-communityData")
    }

    @ViewBuilder
    private func communityDataContent(_ communityData: OctopusCommunityData?) -> some View {
        if let communityData {
            VStack(alignment: .leading, spacing: 4) {
                Text("Messages: \(communityData.messageCount.map(String.init) ?? "-")")
                if let gamification = communityData.gamification {
                    Text("Gamification level: \(gamification.level)")
                    // Score is usually nil for other members on iOS — see OctopusGamification.score.
                    Text("Gamification score: \(gamification.score.map(String.init) ?? "n/a")")
                } else {
                    Text("Gamification: disabled for this community")
                        .foregroundColor(.secondary)
                }
            }
            .font(.system(.footnote, design: .monospaced))
        } else {
            Text("Unknown member (client user id not resolved)")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
}
