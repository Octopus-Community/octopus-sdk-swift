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

    init(octopus: OctopusSDK, postId: String, textFocused: Binding<Bool>, hasChanges: Binding<Bool>) {
        _viewModel = Compat.StateObject(wrappedValue: CreateCommentViewModel(octopus: octopus, postId: postId))
        self._textFocused = textFocused
        self._hasChanges = hasChanges
    }

    var body: some View {
        CreateResponseView(
            responseKind: .comment,
            avatar: viewModel.avatar,
            isLoading: viewModel.isLoading,
            sendAvailable: viewModel.sendAvailable,
            text: $viewModel.text,
            picture: $viewModel.picture,
            textFocused: $textFocused,
            alertError: viewModel.alertError,
            textError: viewModel.textError,
            pictureError: viewModel.pictureError,
            send: viewModel.send,
            userProfileTapped: { navigator.push(.currentUserProfile) },
            resetAlertError: { viewModel.alertError = nil })
        .onReceive(viewModel.$hasChanges) {
            hasChanges = $0
        }
    }
}
