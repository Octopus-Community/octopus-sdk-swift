//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

/// Lists the live backend feature envs and switches the Sample to the community the developer picks.
struct FeatureEnvsView: View {
    @StateObjectCompat private var viewModel = FeatureEnvsViewModel()

    var body: some View {
        List {
            if let dropped = viewModel.droppedAtLaunch {
                Section {
                    Text("\(dropped.displayName) is gone (expired or unreachable). The sample went back "
                         + "to its default community.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            if let current = viewModel.currentFeatureEnv {
                Section(header: Text("Current environment")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(current.displayName) · \(current.communityName)").bold()
                        Text(current.apiHost)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Button("Back to the default community") {
                        Task { await viewModel.clearSelection() }
                    }
                    .foregroundColor(.red)
                    .disabled(viewModel.isApplying)
                }
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Retry") {
                        Task { await viewModel.load() }
                    }
                }
            }

            Section(header: Text("Live environments")) {
                if viewModel.isLoading && viewModel.envs.isEmpty {
                    Text("Loading…").foregroundColor(.secondary)
                } else if viewModel.envs.isEmpty && viewModel.errorMessage == nil {
                    Text("No live feature env right now.").foregroundColor(.secondary)
                }
                ForEach(viewModel.envs) { env in
                    FeatureEnvRow(env: env, isApplying: viewModel.isApplying) { community in
                        Task { await viewModel.select(env: env, community: community) }
                    }
                }
            }
        }
        .listStyle(.grouped)
        .navigationBarTitle(Text("Feature Environments"), displayMode: .inline)
        // Pull-to-refresh from iOS 15; below that, the nav-bar button is the only way to reload without
        // leaving the screen. The button is kept everywhere so the action stays discoverable.
        .modify {
            if #available(iOS 15.0, *) {
                $0.refreshable { await viewModel.load() }
            } else {
                $0
            }
        }
        .navigationBarItems(trailing: Button(action: { Task { await viewModel.load() } }) {
            Image(systemName: "arrow.clockwise")
        }.disabled(viewModel.isLoading))
        .hostAppFooter()
        .onAppear {
            Task { await viewModel.load() }
        }
        .onDisappear {
            viewModel.cancelLoad()
            viewModel.acknowledgeDroppedNotice()
        }
    }
}

/// One environment: a header that unfolds its communities.
private struct FeatureEnvRow: View {
    let env: FeatureEnv
    let isApplying: Bool
    let onSelect: (FeatureEnv.Community) -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: { isExpanded.toggle() }) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(env.displayName).bold()
                        Spacer()
                        Text("expires in \(env.expiresInDays()) d")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("\(env.name) · \(env.branch) · \(env.owner)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                // `usableCommunities`, not `communities`: one without an API key cannot be connected to.
                ForEach(env.usableCommunities) { community in
                    Button(action: { onSelect(community) }) {
                        HStack {
                            Text(community.communityName)
                            if let description = community.description {
                                Text("· \(description)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.right.circle")
                        }
                        .padding(.leading, 12)
                    }
                    .disabled(isApplying)
                }
            }
        }
    }
}
