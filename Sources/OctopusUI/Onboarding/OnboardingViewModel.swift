//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus
import OctopusCore

@MainActor
class OnboardingViewModel: ObservableObject {
    @Published private(set) var dismiss = false
    @Published private(set) var isLoading = false
    @Published private(set) var error: DisplayableString?

    let octopus: OctopusSDK
    let communityGuidelines: URL
    let privacyPolicy: URL
    let termsOfUse: URL

    private var storage = [AnyCancellable]()

    init(octopus: OctopusSDK) {
        self.octopus = octopus

        let externalLinksRepository = octopus.core.externalLinksRepository
        communityGuidelines = externalLinksRepository.communityGuidelines
        privacyPolicy = externalLinksRepository.privacyPolicy
        termsOfUse = externalLinksRepository.termsOfUse

        octopus.core.profileRepository
            .profilePublisher
            .sink { [unowned self] profile in
                guard let profile, profile.hasSeenOnboarding, profile.hasAcceptedCgu else { return }
                isLoading = false
                dismiss = true
            }.store(in: &storage)
    }

    func setOnboardingSeenAndCGUAccepted() {
        isLoading = true
        Task {
            await setOnboardingSeenAndCGUAccepted()
        }
    }

    func setOnboardingSeenAndCGUAccepted() async {
        do {
            try await octopus.core.profileRepository.updateCurrentUserProfile(
                with: .init(
                    hasSeenOnboarding: .updated(true),
                    hasAcceptedCgu: .updated(true)
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
