//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import SwiftUI
import Octopus
import OctopusCore

struct ConnectionRouter: ViewModifier {
    @Environment(\.octopusTheme) private var theme
    @Compat.StateObject private var viewModel: ConnectionRouterViewModel

    @Binding var loggedInDone: Bool

    @State private var displaySSOError = false
    @State private var displayableSSOError: DisplayableString?

    init(viewModel: ConnectionRouterViewModel, loggedInDone: Binding<Bool>) {
        _viewModel = Compat.StateObject(wrappedValue: viewModel)
        _loggedInDone = loggedInDone
    }

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $viewModel.openLogin) {
                MagicLinkView(octopus: viewModel.octopus, isLoggedIn: $loggedInDone)
                    .environment(\.dismissModal, $viewModel.openLogin)
            }
            .fullScreenCover(isPresented: $viewModel.openCreateProfile) {
                NavigationView {
                    CreateProfileView(octopus: viewModel.octopus, isLoggedIn: $loggedInDone)
                        .environment(\.dismissModal, $viewModel.openCreateProfile)
                }
                .navigationBarHidden(true)
                .accentColor(theme.colors.primary)
            }
            .alert(
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
            .onReceive(viewModel.$ssoError) { error in
                guard let error else { return }
                displayableSSOError = error
                displaySSOError = true
            }
    }
}

extension View {
    func connectionRouter(viewModel: ConnectionRouterViewModel, loggedInDone: Binding<Bool>) -> some View {
        modifier(ConnectionRouter(viewModel: viewModel, loggedInDone: loggedInDone))
    }
}

@MainActor
class ConnectionRouterViewModel: ObservableObject {
    @Published var openLogin = false
    @Published var openCreateProfile = false

    @Published private(set) var ssoError: DisplayableString?

    let octopus: OctopusSDK
    init(octopus: OctopusSDK) {
        self.octopus = octopus
    }

    func ensureConnected() -> Bool {
        switch octopus.core.connectionRepository.connectionState {
        case .notConnected, .magicLinkSent:
            if case let .sso(config) = octopus.core.connectionRepository.connectionMode {
                config.loginRequired()
            } else {
                openLogin = true
            }
        case let .clientConnected(_, error):
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
        case .profileCreationRequired:
            openCreateProfile = true
        case .connected:
            return true
        }
        return false
    }

    func linkClientUserToOctopusUser() {
        Task {
            await linkClientUserToOctopusUser()
        }
    }

    private func linkClientUserToOctopusUser() async {
        do {
            try await octopus.core.connectionRepository.linkClientUserToOctopusUser()
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
}
