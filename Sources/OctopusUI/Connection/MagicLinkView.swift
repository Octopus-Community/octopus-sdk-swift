//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import SwiftUI
import Octopus
import OctopusCore

struct MagicLinkView: View {
    @Compat.StateObject private var viewModel: MagicLinkViewModel
    @Environment(\.octopusTheme) private var theme
    @Environment(\.dismissModal) var dismissModal

    @State private var displayEmailEntryError = false
    @State private var emailEntryError: MagicLinkEmailEntryError?

    @State private var displayMagicLinkConfirmationError = false
    @State private var magicLinkConfirmationError: MagicLinkConfirmationError?

    init(octopus: OctopusSDK) {
        _viewModel = Compat.StateObject(wrappedValue: MagicLinkViewModel(octopus: octopus))
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .topTrailing) {
                ContentView(state: viewModel.state,
                            sendEmailButtonAvailable: viewModel.buttonAvailable,
                            email: $viewModel.email,
                            sendMagicLink: viewModel.sendMagicLink, enterNewEmail: viewModel.enterNewEmail,
                            checkMagicLinkConfirmed: viewModel.checkMagicLinkConfirmed)
                Button(action: {
                    dismissModal.wrappedValue = false
                }) {
                    Text("Common.Close", bundle: .module)
                        .font(theme.fonts.navBarItem)
                }
                .buttonStyle(.plain)
                .padding()
                NavigationLink(destination: CreateProfileView(octopus: viewModel.octopus),
                               isActive: $viewModel.profileCreationRequired) {
                    EmptyView()
                }.hidden()
            }
            .presentationBackground(Color(.systemBackground))
            .compatAlert(
                "Common.Error",
                isPresented: $displayMagicLinkConfirmationError,
                presenting: magicLinkConfirmationError,
                actions: { _ in },
                message: { error in
                    error.displayMessage.textView
                })
            .compatAlert(
                "Common.Error",
                isPresented: $displayEmailEntryError,
                presenting: emailEntryError,
                actions: { _ in },
                message: { error in
                    error.displayMessage.textView
                })
            .onReceive(viewModel.$isLoggedIn) { isLoggedIn in
                guard isLoggedIn else { return }
                dismissModal.wrappedValue = false
            }
            .onReceive(viewModel.$confirmationError) { magicLinkConfirmationError in
                guard let magicLinkConfirmationError else { return }
                self.magicLinkConfirmationError = magicLinkConfirmationError
                displayMagicLinkConfirmationError = true
            }
            .onReceive(viewModel.$emailEntryError) { emailEntryError in
                guard let emailEntryError else { return }
                self.emailEntryError = emailEntryError
                displayEmailEntryError = true
            }
        }
        .accentColor(theme.colors.primary)
    }
}

private extension MagicLinkEmailEntryError {
    var displayMessage: DisplayableString {
        switch self {
        case .noNetwork:
                .localizationKey("Error.NoNetwork")
        case let .detailedError(detail):
                .localizedString(detail.message)
        case .server, .unknown:
                .localizationKey("Connection.MagicLink.Send.Error.UnknownError")
        }
    }
}

private extension MagicLinkConfirmationError {
    var displayMessage: DisplayableString {
        switch self {
        case .noNetwork:
                .localizationKey("Error.NoNetwork")
        case .magicLinkExpired:
                .localizationKey("Connection.MagicLink.Sent.Error.Expired")
        case .noMagicLink, .needNewMagicLink:
                .localizationKey("Connection.MagicLink.Sent.Error.UnknownError")
        case let .userBanned(explanation):
                .localizedString(explanation)
        case .unknown:
                .localizationKey("Connection.MagicLink.Sent.Error.UnknownError")
        }
    }
}

private struct ContentView: View {
    @Environment(\.octopusTheme) private var theme

    let state: MagicLinkViewModel.State
    let sendEmailButtonAvailable: Bool
    @Binding var email: String
    let sendMagicLink: () -> Void
    let enterNewEmail: () -> Void
    let checkMagicLinkConfirmed: () -> Void


    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 12)
            Image(uiImage: theme.assets.logo)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 44)
            switch state {
            case let .emailEntry(substate):
                EnterEmailView(state: substate, sendEmailButtonAvailable: sendEmailButtonAvailable, email: $email,
                               sendMagicLink: sendMagicLink)
            case let .magicLinkConfirmationPending(email: email, state: substate):
                MagicLinkConfirmationPendingView(state: substate, email: email, enterNewEmail: enterNewEmail,
                                                 checkMagicLinkConfirmed: checkMagicLinkConfirmed)
            }
        }
        .padding(.top)
        .padding(.horizontal, 20)
    }
}

private struct EnterEmailView: View {
    @Environment(\.octopusTheme) private var theme
    let state: MagicLinkViewModel.State.EmailEntryState
    let sendEmailButtonAvailable: Bool
    @Binding var email: String
    var sendMagicLink: () -> Void

    @State private var emailFocused = true

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 40)
            Text("Connection.MagicLink.Title", bundle: .module)
                .font(theme.fonts.title2)
                .fontWeight(.semibold)
            Spacer().frame(height: 8)
            Text("Connection.MagicLink.Description", bundle: .module)
                .font(theme.fonts.body2)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 52)
            OctopusTextInput(
                text: $email, label: "Connection.MagicLink.Email.Description",
                placeholder: "Connection.MagicLink.Email.Placeholder",
                hint: nil, error: nil, isFocused: emailFocused, isDisabled: false) {
                    sendMagicLink()
                }
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .focused($emailFocused)

            Spacer()
            PoweredByOctopusView()
            Spacer().frame(height: 8)
            switch state {
            case .emailNeeded:
                Button(action: sendMagicLink) {
                    Text("Connection.MagicLink.Send.Button", bundle: .module)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(OctopusButtonStyle(.main, enabled: sendEmailButtonAvailable))
                .disabled(!sendEmailButtonAvailable)

            case .emailSending:
                Compat.ProgressView()
                    .frame(width: 60)
            }
            Spacer().frame(height: 8)
        }
    }
}

private struct MagicLinkConfirmationPendingView: View {
    @Environment(\.octopusTheme) private var theme
    let state: MagicLinkViewModel.State.MagicLinkConfirmationPendingState
    let email: String
    let enterNewEmail: () -> Void
    let checkMagicLinkConfirmed: () -> Void

    var body: some View {
        VStack {
            Spacer().frame(height: 40)
            Text("Connection.MagicLink.Sent.Title", bundle: .module)
                .font(theme.fonts.title2)
                .fontWeight(.semibold)
            Spacer().frame(height: 8)
            Text("Connection.MagicLink.Sent.Explanation_email:\(email)", bundle: .module)
                .font(theme.fonts.body2)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 26)
            Text("Connection.MagicLink.Sent.CheckSpams", bundle: .module)
                .font(theme.fonts.body2)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 8)
            Button(action: enterNewEmail) {
                Text("Connection.MagicLink.Sent.ChangeEmail", bundle: .module)
            }
            .buttonStyle(.plain)
            .font(theme.fonts.body2)
            .foregroundColor(theme.colors.link)
            .multilineTextAlignment(.center)
            Spacer()
            switch state {
            case .magicLinkSent, .magicLinkSentButNotOpenedYet:
                if state == .magicLinkSentButNotOpenedYet {
                    Text("Connection.MagicLink.Sent.Error.NotOpenedYet",
                         bundle: .module)
                    .font(theme.fonts.caption1)
                    .foregroundColor(theme.colors.error)
                }
                Button(action: {
                    checkMagicLinkConfirmed()
                }) {
                    Text("Connection.MagicLink.Sent.Refresh.Button", bundle: .module)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(OctopusButtonStyle(.main))
            case .checkingMagicLink:
                Compat.ProgressView()
                    .frame(width: 60)
            }
            Spacer().frame(height: 8)
        }
    }
}


#Preview {
    ContentView(state: .emailEntry(.emailNeeded), sendEmailButtonAvailable: true, email: .constant(""),
                sendMagicLink: { }, enterNewEmail: { }, checkMagicLinkConfirmed: { })
}
