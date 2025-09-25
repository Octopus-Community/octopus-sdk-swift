//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus
import OctopusCore

@MainActor
class ValidateNicknameViewModel: ObservableObject {
    @Published private(set) var dismiss = false
    @Published private(set) var isLoading = false
    @Published private(set) var error: DisplayableString?
    @Published private(set) var nickname: String

    let octopus: OctopusSDK

    private var storage = [AnyCancellable]()

    init(octopus: OctopusSDK) {
        self.octopus = octopus

        nickname = octopus.core.profileRepository.profile?.nickname ?? ""

        octopus.core.profileRepository
            .profilePublisher
            .sink { [unowned self] profile in
                nickname = profile?.nickname ?? ""
                if let profile, profile.hasConfirmedNickname {
                    dismiss = true
                }
            }.store(in: &storage)
    }

    func setNicknameAsConfirmed() {
        isLoading = true
        Task {
            await setNicknameAsConfirmed()
        }
    }

    func setNicknameAsConfirmed() async {
        do {
            try await octopus.core.profileRepository.updateCurrentUserProfile(
                with: .init(
                    hasConfirmedNickname: .updated(true)
                ))
        } catch {
            switch error {
            case let .validation(argumentError):
                for (_, errors) in argumentError.errors {
                    let multiErrorLocalizedString = errors.map(\.localizedMessage).joined(separator: "\n- ")
                    self.error = .localizedString(multiErrorLocalizedString)
                }
            case let .serverCall(serverError):
                self.error = serverError.displayableMessage
            }
            isLoading = false
        }
    }
}
