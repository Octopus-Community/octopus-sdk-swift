//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus

/// View model of SyncFollowGroupsView.
@MainActor
class SyncFollowGroupsViewModel: ObservableObject {
    let octopus: OctopusSDK = OctopusSDKProvider.instance.octopus

    @Published var editableActions: [EditableAction] = [EditableAction()]
    @Published var results: [OctopusSyncFollowGroup.Result] = []
    @Published var errorDescription: String?
    @Published var groups: [OctopusGroup] = []

    private var storage = [AnyCancellable]()

    init() {
        octopus.$groups
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in
                groups = $0
            }.store(in: &storage)
        Task { try? await octopus.fetchGroups() }
    }

    func addAction() {
        editableActions.append(EditableAction())
    }

    func removeActions(at offsets: IndexSet) {
        editableActions.remove(atOffsets: offsets)
    }

    func sync() {
        Task { await performSync() }
    }

    private func performSync() async {
        errorDescription = nil
        results = []
        let actions = editableActions.map {
            OctopusSyncFollowGroup.Action(
                groupId: $0.groupId, followed: $0.followed, actionDate: $0.actionDate)
        }
        do {
            results = try await octopus.syncFollowGroups(actions: actions)
        } catch {
            errorDescription = error.debugDescription
        }
    }

    struct EditableAction: Identifiable {
        let id = UUID()
        var groupId: String = ""
        var followed: Bool = true
        var actionDate: Date = Date()
    }
}
