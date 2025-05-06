//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus
import OctopusCore

@MainActor
class DeleteAccountViewModel: ObservableObject {
    @Published private(set) var deleteAccountInProgress = false
    @Published private(set) var error: DisplayableString?
    @Published var accountDeleted = false

    @Published private(set) var email = CommunityInfos.email

    private var storage = [AnyCancellable]()
    let octopus: OctopusSDK

    init(octopus: OctopusSDK, mainFlowPath: MainFlowPath) {
        self.octopus = octopus

        Publishers.CombineLatest(
            $deleteAccountInProgress,
            $accountDeleted
        ).sink {
            let shouldBeLocked = $0 || $1
            guard shouldBeLocked != mainFlowPath.isLocked else { return }
            mainFlowPath.isLocked = shouldBeLocked
        }.store(in: &storage)
    }

    func deleteAccount(reason: DeleteAccountReason) {
        Task {
            await deleteAccount(reason: reason)
        }
    }

    private func deleteAccount(reason: DeleteAccountReason) async {
        deleteAccountInProgress = true
        do {
            try await octopus.core.connectionRepository.deleteAccount(reason: reason)
            accountDeleted = true
            deleteAccountInProgress = false
        } catch {
            deleteAccountInProgress = false
            self.error = error.displayableMessage
        }
    }
}
