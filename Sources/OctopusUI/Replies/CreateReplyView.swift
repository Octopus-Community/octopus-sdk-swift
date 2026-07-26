//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

struct CreateReplyView: View {
    @EnvironmentObject var navigator: Navigator<MainFlowScreen>
    @Environment(\.octopusTheme) private var theme
    @Environment(\.presentationMode) private var presentationMode

    @Compat.StateObject private var viewModel: CreateReplyViewModel

    @Binding var textFocused: Bool
    @Binding var hasChanges: Bool

    let ensureConnected: (UserAction) -> Bool

    init(octopus: OctopusSDK, commentId: String,
         translationStore: ContentTranslationPreferenceStore,
         textFocused: Binding<Bool>, hasChanges: Binding<Bool>,
         ensureConnected: @escaping (UserAction) -> Bool) {
        _viewModel = Compat.StateObject(wrappedValue: CreateReplyViewModel(
            octopus: octopus, commentId: commentId,
            translationStore: translationStore,
            ensureConnected: ensureConnected))
        self._textFocused = textFocused
        self._hasChanges = hasChanges
        self.ensureConnected = ensureConnected
    }

    var body: some View {
        CreateResponseView(
            responseKind: .reply,
            isLoading: viewModel.isLoading,
            sendAvailable: viewModel.sendAvailable,
            displayCguText: !viewModel.userHasAcceptedCgu && viewModel.sendAvailable
                && !viewModel.termsAcceptanceMode.isExplicit,
            picturesEnabled: viewModel.picturesEnabled,
            text: $viewModel.text,
            picture: $viewModel.picture,
            textFocused: $textFocused,
            alertError: viewModel.alertError,
            textError: viewModel.textError,
            pictureError: viewModel.pictureError,
            termsOfUseUrl: viewModel.termsOfUseUrl,
            privacyPolicyUrl: viewModel.privacyPolicyUrl,
            communityGuidelinesUrl: viewModel.communityGuidelinesUrl,
            send: viewModel.send,
            userProfileTapped: { dispatchCurrentUserProfileTap(octopus: viewModel.octopus, navigator: navigator) },
            resetAlertError: { viewModel.alertError = nil },
            ensureConnected: ensureConnected)
        .onReceive(viewModel.$hasChanges) {
            hasChanges = $0
        }
        .termsConsentSheet(
            isPresented: $viewModel.displayConsentSheet,
            mode: viewModel.termsAcceptanceMode,
            contribution: .reply,
            termsUrl: viewModel.termsOfUseUrl,
            privacyUrl: viewModel.privacyPolicyUrl,
            rulesUrl: viewModel.communityGuidelinesUrl,
            onAccept: { viewModel.acceptConsentAndSend() })
    }
}
