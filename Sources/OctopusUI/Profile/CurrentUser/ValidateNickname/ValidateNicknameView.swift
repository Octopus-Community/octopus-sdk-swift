//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Combine
import Foundation
import SwiftUI
import Octopus
import OctopusCore

/// Shown before a member's first post, comment or reply goes, to choose their nickname and optionally their
/// picture. It cannot be dismissed: it closes once the nickname is confirmed, which lets the contribution go, or
/// from the alert of a failed confirmation, which drops the contribution.
struct ValidateNicknameView: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.trackingApi) var trackingApi

    @Compat.StateObject private var viewModel: ValidateNicknameViewModel
    @Binding var isPresented: Bool
    /// Closes the screen without sending the contribution.
    let close: () -> Void

    @State private var nicknameFocused = true
    @State private var displayFailure = false
    @State private var displayedFailure: DisplayableString?

    init(octopus: OctopusSDK, contribution: UserAction, isPresented: Binding<Bool>, close: @escaping () -> Void) {
        _viewModel = Compat.StateObject(wrappedValue: ValidateNicknameViewModel(octopus: octopus,
                                                                                 contribution: contribution))
        _isPresented = isPresented
        self.close = close
    }

    var body: some View {
        ContentView(
            form: viewModel.form,
            contribution: viewModel.contribution,
            isSubmitting: viewModel.isSubmitting,
            canEditPicture: viewModel.canEditPicture,
            avatarColorSeed: viewModel.avatarColorSeed,
            communityAvatar: viewModel.communityAvatar,
            picture: $viewModel.picture,
            nicknameFocused: $nicknameFocused,
            alertErrors: viewModel.$alertError,
            displayFailure: $displayFailure,
            failure: displayedFailure,
            edit: viewModel.edit,
            clear: viewModel.clear,
            pick: viewModel.pick(suggestion:),
            submit: viewModel.submit,
            submitFromKeyboard: submitFromKeyboard,
            close: close)
        .onReceive(viewModel.$failure) { failure in
            guard let failure else { return }
            displayedFailure = failure
            displayFailure = true
        }
        .emitScreenDisplayed(.validateNickname, trackingApi: trackingApi)
        .onReceive(viewModel.$dismiss) { shouldDismiss in
            guard shouldDismiss else { return }
            isPresented = false
        }
        .presentationBackground(theme.colors.background)
        .accentColor(theme.colors.primary)
    }

    /// The return key resigns the field: give the focus back so the keyboard stays up while the update runs.
    /// It is given back on the next run loop, as the field may resign only after this call.
    private func submitFromKeyboard() {
        viewModel.submit()
        nicknameFocused = true
        DispatchQueue.main.async { nicknameFocused = true }
    }
}

private struct ContentView<AlertErrors: Publisher>: View
where AlertErrors.Output == DisplayableString?, AlertErrors.Failure == Never {
    @Environment(\.octopusTheme) private var theme

    let form: NicknameChoiceForm
    let contribution: UserAction
    let isSubmitting: Bool
    let canEditPicture: Bool
    let avatarColorSeed: String?
    let communityAvatar: DefaultAvatar?
    @Binding var picture: EditProfileViewModel.Picture
    @Binding var nicknameFocused: Bool
    /// Errors about the picked picture, shown in an alert that only offers OK.
    let alertErrors: AlertErrors
    /// Whether the alert of a failed confirmation is shown.
    @Binding var displayFailure: Bool
    /// The message of the alert of a failed confirmation.
    let failure: DisplayableString?
    let edit: (String) -> Void
    let clear: () -> Void
    let pick: (String) -> Void
    let submit: () -> Void
    let submitFromKeyboard: () -> Void
    /// Closes the screen without sending the contribution.
    let close: () -> Void

    private let pictureSize: CGFloat = 72

    var body: some View {
        VStack(spacing: 0) {
            Compat.ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 40)
                    avatar
                    if let pictureError = form.pictureError {
                        Spacer().frame(height: 4)
                        pictureError.textView
                            .font(theme.fonts.caption2)
                            .foregroundColor(theme.colors.error)
                            .multilineTextAlignment(.center)
                    }
                    Spacer().frame(height: 16)
                    Text("ValidateNickname.Choose.Title", bundle: .module)
                        .font(theme.fonts.title1)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.colors.gray900)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Spacer().frame(height: 8)
                    Text("ValidateNickname.Choose.Subtitle", bundle: .module)
                        .font(theme.fonts.body2)
                        .foregroundColor(theme.colors.gray700)
                        .multilineTextAlignment(.center)
                    Spacer().frame(height: 24)
                    nicknameField
                    if !form.suggestions.isEmpty {
                        // No spacer above: the chips' 44pt tap targets leave the gap around them.
                        NicknameSuggestionsView(suggestions: form.suggestions, pick: pick)
                    }
                }
            }
            // The two alerts hang on sibling views (the scroll view and the button): before iOS 14.5, an alert
            // hides the alerts of the views it contains, and a view shows only one of its own alerts.
            .errorAlert(alertErrors)
            Spacer().frame(height: 16)
            Button(action: submit) {
                Group {
                    if isSubmitting {
                        Compat.ProgressView(tint: theme.colors.onPrimary)
                    } else {
                        Text(contribution.nicknameChoiceButtonKey, bundle: .module)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(OctopusButtonStyle(.main, enabled: form.canSubmit))
            .disabled(!form.canSubmit || isSubmitting)
            // While submitting the button only shows a spinner: keep naming the contribution.
            .accessibilityLabelInBundle(contribution.nicknameChoiceButtonKey)
            // After `disabled`, so that its buttons stay enabled. OK lets the member try again, Close leaves the
            // screen without sending the contribution.
            .compatAlert("Common.Error", isPresented: $displayFailure, message: failure?.textView,
                         primaryButton: "Common.Ok", primaryAction: {},
                         secondaryButton: "Common.Close", secondaryAction: close)
            Spacer().frame(height: 16)
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var avatar: some View {
        if canEditPicture {
            EditablePictureView(picture: $picture, nickname: form.nickname,
                                avatarColorSeed: avatarColorSeed, communityAvatar: communityAvatar,
                                openPhotosPicker: false,
                                pictureSize: pictureSize)
                .frame(width: pictureSize, height: pictureSize)
        } else {
            AuthorAvatarView(avatar: fixedAvatar)
                .frame(width: pictureSize, height: pictureSize)
        }
    }

    /// The avatar without edit badge: the host's picture, or the initials of the nickname being typed (on the
    /// community's default when it chose one).
    private var fixedAvatar: Author.Avatar {
        let nickname = form.nickname
        if case let .unchanged(url?) = picture { return .image(url: url, name: nickname) }
        return .typing(nickname: nickname, colorSeed: avatarColorSeed, community: communityAvatar)
    }

    private var nicknameBinding: Binding<String> {
        Binding(get: { form.nickname }, set: { edit($0) })
    }

    private var nicknameField: some View {
        OctopusInput(error: form.error, isFocused: nicknameFocused) {
            HStack(spacing: 0) {
                OctopusTextField(text: nicknameBinding, placeholder: "Profile.Nickname.Placeholder", lineLimit: 1,
                                 onCommit: submitFromKeyboard)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .focused($nicknameFocused)
                    .padding(.leading, 12)
                    .padding(.vertical, 12)
                    // The clear button takes the trailing margin.
                    .padding(.trailing, form.showsClearButton ? 0 : 12)
                if form.showsClearButton {
                    Button(action: clear) {
                        // Sized by the field's own font, so the icon follows the text size.
                        IconImage(theme.assets.icons.common.clearText)
                            .font(theme.fonts.body2)
                            .foregroundColor(theme.colors.gray700)
                            // A tap target of at least 44pt around the icon, its trailing edge on the field's
                            // border. It takes the margins rather than the text's room, so a tap meant to place
                            // the cursor never clears the field. Its height is the field's own (see fixedSize
                            // below), so that the icon appearing never changes the field's height.
                            .padding(.horizontal, 12)
                            .frame(minWidth: 44, minHeight: 44, maxHeight: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabelInBundle("Common.Delete")
                }
            }
            // Lets the clear button take the height of the text field instead of growing it.
            .fixedSize(horizontal: false, vertical: true)
            .contentShape(Rectangle())
            .onTapGesture { nicknameFocused = true }
        }
    }
}

#Preview {
    ContentView(
        form: NicknameChoiceForm(currentNickname: "user-2ab2", forceNicknameChoice: false),
        contribution: .post,
        isSubmitting: false,
        canEditPicture: true,
        avatarColorSeed: "user-2ab2",
        communityAvatar: nil,
        picture: .constant(.unchanged(nil)),
        nicknameFocused: .constant(true),
        alertErrors: Just<DisplayableString?>(nil),
        displayFailure: .constant(false),
        failure: nil,
        edit: { _ in },
        clear: { },
        pick: { _ in },
        submit: { },
        submitFromKeyboard: { },
        close: { })
}
