//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import SwiftUI
import Octopus
import OctopusCore

struct ConnectionRouter: ViewModifier {
    @Environment(\.octopusTheme) private var theme
    @Binding var noConnectedReplacementAction: ConnectedActionReplacement?
    /// Called when the member closes the nickname choice screen without confirming their nickname, so that the
    /// composer it held a contribution for drops it.
    let onNicknameChoiceClosed: (@MainActor () -> Void)?

    @Compat.StateObject private var viewModel: ConnectionRouterViewModel

    @State private var openNicknameValidation = false
    @State private var nicknameChoiceContribution: UserAction = .post
    @State private var displayLoadConfigError = false
    @State private var displaySSOError = false
    @State private var displayableSSOError: DisplayableString?
    @State private var displayBanned = false
    @State private var bannedMessage: DisplayableString?

    init(octopus: OctopusSDK, noConnectedReplacementAction: Binding<ConnectedActionReplacement?>,
         onNicknameChoiceClosed: (@MainActor () -> Void)?) {
        _viewModel = Compat.StateObject(wrappedValue: ConnectionRouterViewModel(octopus: octopus))
        _noConnectedReplacementAction = noConnectedReplacementAction
        self.onNicknameChoiceClosed = onNicknameChoiceClosed
    }

    func body(content: Content) -> some View {
        content
            .octopusFullScreenCover(isPresented: $openNicknameValidation) {
                ValidateNicknameView(octopus: viewModel.octopus, contribution: nicknameChoiceContribution,
                                     isPresented: $openNicknameValidation,
                                     close: {
                                         onNicknameChoiceClosed?()
                                         openNicknameValidation = false
                                     })
            }
            .compatAlert(
                "Common.Error",
                isPresented: $displaySSOError,
                presenting: displayableSSOError,
                actions: { _ in
                    Button(action: viewModel.linkClientUserToOctopusUser) {
                        Text("Common.Retry", bundle: .module)
                    }
                    Button(action: {}) {
                        Text("Common.Cancel", bundle: .module)
                    }
                },
                message: { error in
                    error.textView
                })
            // No Retry: a ban is the server's settled answer, no exchange lifts it.
            .compatAlert(
                "Common.Error",
                isPresented: $displayBanned,
                presenting: bannedMessage,
                actions: { _ in
                    Button(action: {}) {
                        Text("Common.Ok", bundle: .module)
                    }
                },
                message: { error in
                    error.textView
                })
            .compatAlert(
                "Common.Error",
                isPresented: $displayLoadConfigError,
                presenting: LocalizedStringKey("Error.Unknown"),
                actions: { _ in
                    Button(action: viewModel.fetchConfig) {
                        Text("Common.Retry", bundle: .module)
                    }
                    Button(action: {}) {
                        Text("Common.Cancel", bundle: .module)
                    }
                },
                message: { error in
                    Text(error, bundle: .module)
                })
            .onReceive(viewModel.$ssoError) { error in
                displayableSSOError = error
                displaySSOError = error != nil
            }
            .onReceive(viewModel.$displayLoadConfigError) { display in
                guard display else { return }
                displayLoadConfigError = display
            }
            .onValueChanged(of: noConnectedReplacementAction) {
                defer { noConnectedReplacementAction = nil }
                switch $0 {
                case let .validateNickname(contribution):
                    nicknameChoiceContribution = contribution
                    openNicknameValidation = true
                case .loadConfig: displayLoadConfigError = true
                case let .error(error):
                    displayableSSOError = error
                    displaySSOError = true
                    viewModel.linkClientUserToOctopusUser()
                case let .banned(message):
                    bannedMessage = message
                    displayBanned = true
                case .none: break
                }
            }
    }
}

extension View {
    /// - Parameter onNicknameChoiceClosed: called when the member closes the nickname choice screen without
    ///   confirming their nickname. A view whose contributions can open that screen passes it so the held
    ///   contribution is dropped.
    func connectionRouter(octopus: OctopusSDK, noConnectedReplacementAction: Binding<ConnectedActionReplacement?>,
                          onNicknameChoiceClosed: (@MainActor () -> Void)? = nil) -> some View {
        modifier(ConnectionRouter(octopus: octopus, noConnectedReplacementAction: noConnectedReplacementAction,
                                  onNicknameChoiceClosed: onNicknameChoiceClosed))
    }
}

@MainActor
class ConnectionRouterViewModel: ObservableObject {
    @Published private(set) var ssoError: DisplayableString?
    @Published private(set) var displayLoadConfigError = false

    let octopus: OctopusSDK
    init(octopus: OctopusSDK) {
        self.octopus = octopus
    }

    func linkClientUserToOctopusUser() {
        Task {
            await linkClientUserToOctopusUser()
        }
    }

    func fetchConfig() {
        Task {
            await fetchConfig()
        }
    }

    private func linkClientUserToOctopusUser() async {
        do {
            try await octopus.core.connectionRepository.linkClientUserToOctopusUser()
            ssoError = nil
        } catch {
            switch error {
            case let .detailedErrors(errors):
                if let error = errors.first(where: { $0.reason == .userBanned }) {
                    ssoError = .localizedString(error.message)
                } else {
                    fallthrough
                }
            default:
                ssoError = .localizationKey("Connection.SSO.Error.Unknown")
            }
        }
    }

    private func fetchConfig() async {
        do {
            try await octopus.core.configRepository.refreshCommunityConfig()
        } catch {
            displayLoadConfigError = true
        }
    }
}
