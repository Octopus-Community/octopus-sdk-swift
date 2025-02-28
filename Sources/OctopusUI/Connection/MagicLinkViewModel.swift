//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus
import OctopusCore

@MainActor
class MagicLinkViewModel: ObservableObject {

    enum State {
        case emailEntry(EmailEntryState)
        case magicLinkConfirmationPending(email: String, state: MagicLinkConfirmationPendingState)

        enum EmailEntryState {
            case emailNeeded
            case emailSending
        }

        enum MagicLinkConfirmationPendingState {
            case magicLinkSent
            case magicLinkSentButNotOpenedYet
            case checkingMagicLink
        }
    }


    @Published var profileCreationRequired = false
    @Published private(set) var isLoggedIn = false
    @Published private(set) var emailEntryError: MagicLinkEmailEntryError?
    @Published private(set) var confirmationError: MagicLinkConfirmationError?
    @Published private(set) var state: State = .emailEntry(.emailNeeded)
    @Published var email = ""
    var buttonAvailable: Bool { email.isValidEmail }

    let octopus: OctopusSDK

    private var storage = [AnyCancellable]()

    init(octopus: OctopusSDK) {
        self.octopus = octopus

        octopus.core.connectionRepository.connectionStatePublisher.sink { [unowned self] in
            switch $0 {
            case .notConnected:
                state = .emailEntry(.emailNeeded)
            case let .magicLinkSent(request):
                state = .magicLinkConfirmationPending(email: request.email, state: .magicLinkSent)
                if let error = request.error {
                    processConfirmationError(error: error)
                }
            case .profileCreationRequired:
                profileCreationRequired = true
            case .connected:
                isLoggedIn = true
            case .clientConnected:
                // dev error, this should not happen !
                break
            }
        }.store(in: &storage)
    }

    func sendMagicLink() {
        guard case .emailEntry(.emailNeeded) = state else { return }
        guard email.isValidEmail else { return }

        Task { [octopus] in
            state = .emailEntry(.emailSending)
            do {
                try await octopus.core.connectionRepository.sendMagicLink(to: email)
                state = .magicLinkConfirmationPending(email: email, state: .magicLinkSent)
            } catch let error as MagicLinkEmailEntryError {
                state = .emailEntry(.emailNeeded)
                emailEntryError = error
           } catch {
               // this block should not be called because we ensure that `sendMagicLink` only throws a
               // MagicLinkEmailEntryError
               state = .emailEntry(.emailNeeded)
               emailEntryError = .server(.unknown(error))
           }
        }
    }

    func enterNewEmail() {
        guard case .magicLinkConfirmationPending = state else { return }
        octopus.core.connectionRepository.cancelMagicLink()
        email = ""
        state = .emailEntry(.emailNeeded)
    }

    func checkMagicLinkConfirmed() {
        guard case let .magicLinkConfirmationPending(email, state: .magicLinkSent) = state else { return }

        Task { [octopus] in
            state = .magicLinkConfirmationPending(email: email, state: .checkingMagicLink)
            do {
                let isConnected = try await octopus.core.connectionRepository.checkMagicLinkConfirmed()
                if !isConnected {
                    state = .magicLinkConfirmationPending(email: email, state: .magicLinkSentButNotOpenedYet)
                }
            } catch let error as MagicLinkConfirmationError {
                processConfirmationError(error: error)
            } catch {
                // this block should not be called because we ensure that `checkMagicLinkConfirmed` only throws a
                // MagicLinkConnectionError
                processConfirmationError(error: .unknown(error))
            }
        }
    }

    private func processConfirmationError(error: MagicLinkConfirmationError) {
        switch error {
        case .noNetwork, .unknown:
            state = .magicLinkConfirmationPending(email: email, state: .magicLinkSent)
            confirmationError = error
        case .magicLinkExpired:
            octopus.core.connectionRepository.cancelMagicLink()
            confirmationError = error
        case .userBanned:
            octopus.core.connectionRepository.cancelMagicLink()
            confirmationError = error
        case .noMagicLink: // developer error, should not happen
            fallthrough
        case .needNewMagicLink:
            octopus.core.connectionRepository.cancelMagicLink()
            confirmationError = error
        }
    }
}
