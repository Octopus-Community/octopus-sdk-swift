//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus

@MainActor
class SettingsListViewModel: ObservableObject {

    let octopus: OctopusSDK
    let octopusOwnedProfile: Bool
    @Published private(set) var logoutInProgress = false
    @Published var logoutDone = false
    @Published private(set) var error: Error?
    @Published private(set) var popToRoot = false

    private var storage = [AnyCancellable]()

    init(octopus: OctopusSDK, mainFlowPath: MainFlowPath) {
        self.octopus = octopus
        switch octopus.core.connectionRepository.connectionMode {
        case .octopus:
            octopusOwnedProfile = true
        case .sso:
            octopusOwnedProfile = false
        }

        Publishers.CombineLatest(
            $logoutInProgress,
            $logoutDone
        ).sink {
            let shouldBeLocked = $0 || $1
            guard shouldBeLocked != mainFlowPath.isLocked else { return }
            mainFlowPath.isLocked = shouldBeLocked
        }.store(in: &storage)
    }

    func logout() {
        Task {
            logoutInProgress = true
            do {
                try await octopus.core.connectionRepository.logout()
                logoutDone = true
                logoutInProgress = false
            } catch {
                logoutInProgress = false
                self.error = error
            }
        }
    }
}
