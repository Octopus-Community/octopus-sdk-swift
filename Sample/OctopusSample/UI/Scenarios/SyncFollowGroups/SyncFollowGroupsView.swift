//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus
import OctopusUI

/// A view that demonstrates the batch sync-follow-groups API.
struct SyncFollowGroupsView: View {
    @StateObjectCompat private var viewModel = SyncFollowGroupsViewModel()

    var body: some View {
        List {
            Section(header: Text("Actions")) {
                ForEach(viewModel.editableActions) { action in
                    SyncFollowActionRow(
                        action: binding(for: action.id),
                        groups: viewModel.groups
                    )
                }
                .onDelete(perform: viewModel.removeActions)

                Button("Add action") {
                    viewModel.addAction()
                }
            }

            Section {
                Button("Sync") {
                    viewModel.sync()
                }
            }

            if let errorDescription = viewModel.errorDescription {
                Section(header: Text("Error")) {
                    Text(errorDescription)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            if !viewModel.results.isEmpty {
                Section(header: Text("Results")) {
                    ForEach(viewModel.results.indices, id: \.self) { index in
                        let result = viewModel.results[index]
                        HStack {
                            Text(result.groupId)
                            Spacer()
                            Text(String(describing: result.status))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationBarTitle(Text("Sync Follow Groups"), displayMode: .inline)
    }

    private func binding(
        for id: SyncFollowGroupsViewModel.EditableAction.ID
    ) -> Binding<SyncFollowGroupsViewModel.EditableAction> {
        Binding(
            get: {
                viewModel.editableActions.first(where: { $0.id == id })
                    ?? SyncFollowGroupsViewModel.EditableAction()
            },
            set: { newValue in
                if let idx = viewModel.editableActions.firstIndex(where: { $0.id == id }) {
                    viewModel.editableActions[idx] = newValue
                }
            }
        )
    }
}

private struct SyncFollowActionRow: View {
    @Binding var action: SyncFollowGroupsViewModel.EditableAction
    let groups: [OctopusGroup]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            groupPicker
            Toggle("Followed", isOn: $action.followed)
            DatePicker("Action date", selection: $action.actionDate)
        }
    }

    @ViewBuilder
    private var groupPicker: some View {
        let picker = Picker(selection: $action.groupId, label: Text("Group")) {
            Text("Select a group").tag("")
            ForEach(groups, id: \.id) { group in
                Text(label(for: group)).tag(group.id as String)
            }
        }
        if #available(iOS 14.0, *) {
            picker.pickerStyle(.menu)
        } else {
            picker
        }
    }

    private func label(for group: OctopusGroup) -> String {
        var badges: [String] = []
        badges.append(group.isFollowed ? "followed" : "not followed")
        if !group.canChangeFollowStatus {
            badges.append("locked")
        }
        return "\(group.name) (\(badges.joined(separator: ", ")))"
    }
}
