//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import SwiftUI
import Octopus
import OctopusCore

struct ConnectionRouter: ViewModifier {
    @Environment(\.octopusTheme) private var theme
    let octopus: OctopusSDK
    @Binding var noConnectedReplacementAction: ConnectedActionReplacement?

    @Compat.StateObject private var viewModel: ConnectionRouterViewModel

    @State private var openLogin = false
    @State private var openCreateProfile = false
    @State private var displaySSOError = false
    @State private var displayableSSOError: DisplayableString?

    init(octopus: OctopusSDK, noConnectedReplacementAction: Binding<ConnectedActionReplacement?>) {
        self.octopus = octopus
        _viewModel = Compat.StateObject(wrappedValue: ConnectionRouterViewModel(octopus: octopus))
        _noConnectedReplacementAction = noConnectedReplacementAction
    }

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $openLogin) {
                MagicLinkView(octopus: octopus)
                    .environment(\.dismissModal, $openLogin)
            }
            .fullScreenCover(isPresented: $openCreateProfile) {
                NavigationView {
                    CreateProfileView(octopus: octopus)
                        .environment(\.dismissModal, $openCreateProfile)
                }
                .navigationBarHidden(true)
                .accentColor(theme.colors.primary)
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
            .onReceive(viewModel.$ssoError) { error in
                guard let error else { return }
                displayableSSOError = error
                displaySSOError = true
            }
            .onValueChanged(of: noConnectedReplacementAction) {
                defer { noConnectedReplacementAction = nil }
                switch $0 {
                case .login: openLogin = true
                case .createProfile: openCreateProfile = true
                case let .ssoError(error):
                    displayableSSOError = error
                    displaySSOError = true
                case .none: break
                }
            }
    }
}

extension View {
    func connectionRouter(octopus: OctopusSDK, noConnectedReplacementAction: Binding<ConnectedActionReplacement?>) -> some View {
        modifier(ConnectionRouter(octopus: octopus, noConnectedReplacementAction: noConnectedReplacementAction))
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
