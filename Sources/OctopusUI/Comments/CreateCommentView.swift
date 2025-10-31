//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Octopus

struct CreateCommentView: View {
    @EnvironmentObject var navigator: Navigator<MainFlowScreen>
    @Environment(\.octopusTheme) private var theme
    @Environment(\.presentationMode) private var presentationMode

    @Compat.StateObject private var viewModel: CreateCommentViewModel

    @Binding var textFocused: Bool
    @Binding var hasChanges: Bool

    let ensureConnected: (UserAction) -> Bool

    init(octopus: OctopusSDK, postId: String,
         translationStore: ContentTranslationPreferenceStore,
         textFocused: Binding<Bool>, hasChanges: Binding<Bool>,
         ensureConnected: @escaping (UserAction) -> Bool) {
        _viewModel = Compat.StateObject(wrappedValue: CreateCommentViewModel(
            octopus: octopus, postId: postId,
            translationStore: translationStore,
            ensureConnected: ensureConnected))
        self._textFocused = textFocused
        self._hasChanges = hasChanges
        self.ensureConnected = ensureConnected
    }

    var body: some View {
        CreateResponseView(
            responseKind: .comment,
            isLoading: viewModel.isLoading,
            sendAvailable: viewModel.sendAvailable,
            displayCguText: !viewModel.userHasAcceptedCgu && viewModel.sendAvailable,
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
            userProfileTapped: { navigator.push(.currentUserProfile) },
            resetAlertError: { viewModel.alertError = nil },
            ensureConnected: ensureConnected)
        .onReceive(viewModel.$hasChanges) {
            hasChanges = $0
        }
    }
}
