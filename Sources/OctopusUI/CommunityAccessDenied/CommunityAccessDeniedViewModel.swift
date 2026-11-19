//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import UIKit
import Octopus
import OctopusCore
import os

@MainActor
class CommunityAccessDeniedViewModel: ObservableObject {
    /// What the screen displays, `nil` until an access state says the access is denied.
    @Published private(set) var content: CommunityAccessDeniedContent?
    /// Whether the return of a member whose account was deleted is running.
    @Published private(set) var isReturning = false
    @Published private(set) var error: DisplayableString?

    // Plain `throws`: a typed throws clause in a function type crashes below iOS 18.
    private let returnAfterAccountDeletion: () async throws -> Void
    private let refreshAccess: () async -> Void
    /// The language the host app forces, `nil` to follow the system.
    private let overridenLocale: () -> Locale?
    /// The member's tone, read when a sentence is written.
    private let textTone: () -> TextTone
    /// The latest access, which describes a ban found during the return.
    private var userConfig: UserConfig?
    private var storage = [AnyCancellable]()

    init(userConfigPublisher: AnyPublisher<UserConfig?, Never>,
         refreshAccess: @escaping () async -> Void,
         returnAfterAccountDeletion: @escaping () async throws -> Void,
         overridenLocale: (() -> Locale?)? = nil,
         textTone: (() -> TextTone)? = nil,
         appComesBackPublisher: AnyPublisher<Void, Never>? = nil) {
        self.returnAfterAccountDeletion = returnAfterAccountDeletion
        self.refreshAccess = refreshAccess
        self.overridenLocale = overridenLocale ?? { nil }
        self.textTone = textTone ?? { .formal }

        userConfigPublisher.sink { [unowned self] in
            self.userConfig = $0
            // Once the access is back, the community takes the place of this screen by itself, also when the SDK
            // is presented modally: what the screen displayed is kept until then, rather than going blank.
            if let content = CommunityAccessDeniedContent(userConfig: $0) {
                self.content = content
            }
        }.store(in: &storage)

        Task {
            await refreshAccess()
        }

        // The SDK reads the access again once a day by itself. A user left on this screen who comes back to the
        // app once their access was opened should not wait for that: read it again each time they come back.
        (appComesBackPublisher ?? NotificationCenter.default
            .publisher(for: UIApplication.willEnterForegroundNotification)
            .map { _ in }
            .eraseToAnyPublisher())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                // A return reads the access itself, with the session it gets
                guard let self, !self.isReturning else { return }
                Task { [weak self] in
                    await self?.refreshAccess()
                }
            }.store(in: &storage)
    }

    convenience init(octopus: OctopusSDK) {
        let configRepository = octopus.core.configRepository
        let connectionRepository = octopus.core.connectionRepository
        self.init(
            userConfigPublisher: configRepository.userConfigPublisher,
            refreshAccess: {
                do {
                    try await configRepository.refreshCommunityAccess()
                } catch {
                    if #available(iOS 14, *) {
                        Logger.config.trace("Error while refreshing community access: \(error)")
                    }
                }
            },
            returnAfterAccountDeletion: {
                try await connectionRepository.reconnectAfterAccountDeletion()
            },
            overridenLocale: { octopus.core.languageRepository.overridenLocale },
            textTone: { octopus.textTone })
    }

    /// Lets the member whose account was deleted access the community again. Does nothing while a return runs.
    func accessCommunity() {
        guard !isReturning else { return }
        isReturning = true
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.returnAfterAccountDeletion()
            } catch {
                // The member stays on the screen and can tap again
                self.error = Self.displayableError(for: error, userConfig: self.userConfig,
                                                   locale: self.overridenLocale(), tone: self.textTone())
            }
            self.isReturning = false
        }
    }

    /// What to tell the member when the return failed.
    /// - Parameters:
    ///   - userConfig: the access to the community, which describes a ban when it is the reason of the refusal
    ///   - locale: the language the host app forces, `nil` to follow the system
    ///   - tone: the member's tone, which picks the version of the sentences that address the member
    nonisolated static func displayableError(for error: Error, userConfig: UserConfig? = nil,
                                             locale: Locale? = nil, tone: TextTone = .formal) -> DisplayableString {
        guard let connectionError = error as? ConnectionError else { return .unknownError }
        switch connectionError {
        case .noNetwork:
            return .noNetworkError
        case let .detailedErrors(errors):
            // The message of a ban is the server's, written for the member
            if let ban = errors.first(where: { $0.reason == .userBanned }) {
                return CommunityAccessDeniedBanMessage.displayable(
                    userBannedMessage: ban.message, userConfig: userConfig, locale: locale, tone: tone)
            }
            return .unknownError
        default:
            return .unknownError
        }
    }
}
