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
                    // Tagged so the QA pipeline has a deterministic in-app way back from here: preset
                    // 6 of the `communityData` scenario leaves the scenario screen, and walking back
                    // with repeated system Back is a documented Tester trap. On iOS 14+ this screen is
                    // presented as a full-screen cover, so there is no swipe-to-dismiss either — this
                    // button is the only way out. The id is NOT in the shared catalog yet and matches
                    // an Android sample change that is still unmerged; propagating it to the catalog
                    // and to Flutter is a follow-up. The accessibility label matters as much as the id:
                    // an icon-only button otherwise has no textual handle in a dump.
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabelCompat("Close")
                    .accessibilityId("clientProfile-back")
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
                // This id used to sit on the enclosing VStack. SwiftUI propagates a container's
                // identifier onto every descendant text, which SHADOWED the three state ids below:
                // an on-simulator `idb ui describe-all` dump showed zero `clientProfile-data` and five
                // `clientProfile-communityData` instead. Moved onto the heading so the id still
                // resolves — nothing in pm-tools consumes it, unlike the state ids, which are the
                // documented assertion target for the `communityData` scenario's preset 6.
                .accessibilityId("clientProfile-communityData")
            switch viewModel.state {
            case .loading:
                // Carries an id of its own so a dump taken mid-fetch is distinguishable from "the
                // feature is missing" — the Tester's documented conclusion when no id matches. Not in
                // the shared catalog yet; adding it there and to the other platforms is a follow-up.
                loadingIndicator
                    .accessibilityId("clientProfile-loading")
            case let .loaded(communityData):
                communityDataContent(communityData)
            case let .error(message):
                Text("Error: \(message)")
                    .font(.footnote)
                    .foregroundColor(.red)
                    .accessibilityId("clientProfile-error")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }

    @ViewBuilder
    private var loadingIndicator: some View {
        if #available(iOS 14.0, *) {
            // Labelled: a bare ProgressView contributes no text to an accessibility dump.
            ProgressView()
                .accessibilityLabel("Loading community data")
        } else {
            Text("Loading…")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    // The three outcomes carry the cross-platform test ids from the shared pm-tools scenario catalog
    // (`clientProfile-data` / `clientProfile-error` / `clientProfile-unknown`), so the QA pipeline can
    // tell "rendered the stats" from "member unknown" from "fetch failed" without reading pixels.
    @ViewBuilder
    private func communityDataContent(_ communityData: OctopusCommunityData?) -> some View {
        if let communityData {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "Profile id: \(communityData.profileId)")
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
            // `.combine` so the four rows surface as ONE element whose text a dump-driven pipeline can
            // read, instead of four elements each repeating the identifier.
            .accessibilityElement(children: .combine)
            .accessibilityId("clientProfile-data")
        } else {
            Text("Unknown member (client user id not resolved). Either the member has never used the " +
                 "community, or the community is not configured to expose client user ids.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .accessibilityId("clientProfile-unknown")
        }
    }
}
