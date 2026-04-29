//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus
import OctopusUI

struct InitialScreenView: View {
    enum Tab: String, CaseIterable {
        case post = "Post"
        case group = "Group"
    }

    @State private var selectedTab: Tab = .post
    @State private var postId: String = ""
    @State private var initialScreenToDisplay: OctopusInitialScreen?

    @State private var groups: [OctopusGroup] = []
    @State private var groupsCancellable: AnyCancellable?

    private var octopus: OctopusSDK { OctopusSDKProvider.instance.octopus }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Mode", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            switch selectedTab {
            case .post:
                postContent
            case .group:
                groupContent
            }
        }
        .navigationBarTitle("Initial Screen", displayMode: .inline)
        .sheet(item: $initialScreenToDisplay) { screen in
            OctopusUIView(octopus: octopus, initialScreen: screen)
        }
        .onAppear {
            groupsCancellable = octopus.$groups.sink { self.groups = $0 }
            Task { try? await octopus.fetchGroups() }
        }
    }

    private var postContent: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "number")
                    .foregroundColor(.secondary)
                TextField("Enter a Post ID", text: $postId)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
            .padding(.horizontal)

            Button(action: {
                guard !postId.isEmpty else { return }
                initialScreenToDisplay = .post(.init(postId: postId))
            }) {
                HStack {
                    Image(systemName: "arrow.up.right.square")
                    Text("Open Post")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor))
                .foregroundColor(.white)
            }
            .disabled(postId.isEmpty)
            .opacity(postId.isEmpty ? 0.4 : 1)
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top)
    }

    private var groupContent: some View {
        List {
            Section(header: Text("Available Groups")) {
                ForEach(groups, id: \.id) { group in
                    Button(action: {
                        initialScreenToDisplay = .group(.init(groupId: group.id))
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.name)
                                    .font(.body)
                                Text(group.id)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            Section(header: Text("Testing")) {
                Button(action: {
                    initialScreenToDisplay = .group(.init(groupId: "not-existing-group-id"))
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Not existing Group")
                                .foregroundColor(.red)
                            Text("not-existing-group-id")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "xmark.circle")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .listStyle(.grouped)
    }
}

// MARK: - OctopusInitialScreen + Identifiable

extension OctopusInitialScreen: @retroactive Identifiable {
    public var id: String {
        switch self {
        case .mainFeed: "mainFeed"
        case .post(let info): "post-\(info.postId)"
        case .group(let info): "group-\(info.groupId)"
        }
    }
}
