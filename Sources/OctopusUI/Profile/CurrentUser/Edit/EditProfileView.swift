//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import SwiftUI
import Octopus
import PhotosUI

struct EditProfileView: View {
    @Environment(\.octopusTheme) private var theme
    @Compat.StateObject private var viewModel: EditProfileViewModel
    @Environment(\.presentationMode) private var presentationMode

    @State private var displayError = false
    @State private var displayableError: DisplayableString?

    @State private var showChangesWillBeLostAlert = false

    private let bioFocused: Bool
    private let photoPickerFocused: Bool

    init(octopus: OctopusSDK, bioFocused: Bool = false, photoPickerFocused: Bool = false,
         preventDismissAfterUpdate: Bool = false) {
        _viewModel = Compat.StateObject(wrappedValue: EditProfileViewModel(
            octopus: octopus, preventDismissAfterUpdate: preventDismissAfterUpdate))
        self.bioFocused = bioFocused
        self.photoPickerFocused = photoPickerFocused
    }

    var body: some View {
        ContentView(isLoading: viewModel.isLoading,
                    nicknameEditConfig: viewModel.nicknameEditConfig,
                    bioEditConfig: viewModel.bioEditConfig,
                    pictureEditConfig: viewModel.pictureEditConfig,
                    nickname: $viewModel.nickname,
                    bio: $viewModel.bio, picture: $viewModel.picture, nicknameForAvatar: viewModel.nicknameForAvatar,
                    nicknameError: viewModel.nicknameError, bioError: viewModel.bioError,
                    pictureError: viewModel.pictureError, bioFocused: bioFocused, bioMaxLength: viewModel.bioMaxLength,
                    photoPickerFocused: photoPickerFocused
        )
        .navigationBarBackButtonHidden(viewModel.hasChanges)
        .navigationBarTitle(Text("Common.Edit", bundle: .module), displayMode: .inline)
        .toolbar(leading: leadingBarItem, trailing: trailingBarItem,
                 trailingSharedBackgroundVisibility: .hidden)
        .compatAlert(
            "Common.Error",
            isPresented: $displayError,
            presenting: displayableError,
            actions: { _ in

            }, message: { error in
                error.textView
            })
        .onReceive(viewModel.$dismiss) { shouldDismiss in
            guard shouldDismiss else { return }
            presentationMode.wrappedValue.dismiss()
        }
        .onReceive(viewModel.$alertError) { displayableError in
            guard let displayableError else { return }
            self.displayableError = displayableError
            displayError = true
        }
        .modify {
            if #available(iOS 15.0, *) {
                $0.alert(
                    Text("Common.CancelModifications", bundle: .module),
                    isPresented: $showChangesWillBeLostAlert) {
                        Button(L10n("Common.No"), role: .cancel, action: {})
                        Button(L10n("Common.Yes"), role: .destructive, action: {
                            presentationMode.wrappedValue.dismiss()
                        })
                    }
            } else {
                $0.alert(isPresented: $showChangesWillBeLostAlert) {
                    Alert(title: Text("Common.CancelModifications", bundle: .module),
                          primaryButton: .default(Text("Common.No", bundle: .module)),
                          secondaryButton: .destructive(
                            Text("Common.Yes", bundle: .module),
                            action: { presentationMode.wrappedValue.dismiss() }
                          )
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var trailingBarItem: some View {
        if !viewModel.isLoading {
            Button(action: viewModel.updateProfile) {
                Text("Common.Save", bundle: .module)
            }
            .buttonStyle(OctopusButtonStyle(.mid, enabled: viewModel.saveAvailable,
                                            externalVerticalPadding: 5))
            .disabled(!viewModel.saveAvailable)
        } else {
            if #available(iOS 14.0, *) {
                ProgressView()
            } else {
                Button(action: viewModel.updateProfile) {
                    Text("Common.Save", bundle: .module)
                }
                .buttonStyle(OctopusButtonStyle(.mid, enabled: false,
                                                externalVerticalPadding: 5))
                .disabled(true)
            }
        }
    }

    @ViewBuilder
    private var leadingBarItem: some View {
        if viewModel.hasChanges {
            BackButton(action: { showChangesWillBeLostAlert = true })
        } else {
            EmptyView()
        }
    }
}

private struct ContentView: View {
    @Environment(\.octopusTheme) private var theme

    let isLoading: Bool
    let nicknameEditConfig: EditProfileViewModel.FieldEditConfig
    let bioEditConfig: EditProfileViewModel.FieldEditConfig
    let pictureEditConfig: EditProfileViewModel.FieldEditConfig
    @Binding var nickname: String
    @Binding var bio: String
    @Binding var picture: EditProfileViewModel.Picture
    let nicknameForAvatar: String

    let nicknameError: DisplayableString?
    let bioError: DisplayableString?
    let pictureError: DisplayableString?

    let bioFocused: Bool
    let bioMaxLength: Int

    let photoPickerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            EditProfileFormView(
                nicknameEditConfig: nicknameEditConfig,
                bioEditConfig: bioEditConfig,
                pictureEditConfig: pictureEditConfig,
                nickname: $nickname, bio: $bio, picture: $picture, nicknameForAvatar: nicknameForAvatar,
                nicknameError: nicknameError, bioError: bioError, pictureError: pictureError,
                bioFocused: bioFocused, bioMaxLength: bioMaxLength, photoPickerFocused: photoPickerFocused)
            .disabled(isLoading)

            PoweredByOctopusView()
        }
    }
}

private struct EditProfileFormView: View {
    @Environment(\.octopusTheme) private var theme

    let nicknameEditConfig: EditProfileViewModel.FieldEditConfig
    let bioEditConfig: EditProfileViewModel.FieldEditConfig
    let pictureEditConfig: EditProfileViewModel.FieldEditConfig
    @Binding var nickname: String
    @Binding var bio: String
    @Binding var picture: EditProfileViewModel.Picture
    let nicknameForAvatar: String

    let nicknameError: DisplayableString?
    let bioError: DisplayableString?
    let pictureError: DisplayableString?

    let bioMaxLength: Int
    let photoPickerFocused: Bool

    @State private var nicknameFocused = false
    @State private var bioFocused: Bool
    @State private var scrollToBottomOfId: String?

    @State private var displayOpenEditProfileInApp = false
    @State private var openEditProfileInApp: (() -> Void)?

    private let pictureSize: CGFloat = 90

    init(nicknameEditConfig: EditProfileViewModel.FieldEditConfig,
         bioEditConfig: EditProfileViewModel.FieldEditConfig,
         pictureEditConfig: EditProfileViewModel.FieldEditConfig,
         nickname: Binding<String>, bio: Binding<String>, picture: Binding<EditProfileViewModel.Picture>,
         nicknameForAvatar: String,
         nicknameError: DisplayableString?, bioError: DisplayableString?, pictureError: DisplayableString?,
         bioFocused: Bool, bioMaxLength: Int, photoPickerFocused: Bool) {
        _nickname = nickname
        _bio = bio
        _picture = picture
        self.nicknameEditConfig = nicknameEditConfig
        self.bioEditConfig = bioEditConfig
        self.pictureEditConfig = pictureEditConfig
        self.nicknameForAvatar = nicknameForAvatar
        self.nicknameError = nicknameError
        self.bioError = bioError
        self.pictureError = pictureError
        _bioFocused = .init(initialValue: bioEditConfig.fieldIsEditable ? bioFocused : false)
        self.bioMaxLength = bioMaxLength
        self.photoPickerFocused = pictureEditConfig.fieldIsEditable ? photoPickerFocused : false
    }

    var body: some View {
        Compat.ScrollView(scrollToId: $scrollToBottomOfId, idAnchor: .top) {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 6)
                HStack {
                    Spacer()
                    PictureView(picture: $picture, nickname: nicknameForAvatar, openPhotosPicker: photoPickerFocused,
                                pictureSize: pictureSize)
                        .frame(width: pictureSize, height: pictureSize)
                        .disabled(!pictureEditConfig.fieldIsEditable)
                        .opacity(1.0) // Prevents fading due to disabled
                        .modify {
                            if let callback = pictureEditConfig.callback {
                                $0.onTapGesture {
                                    openEditProfileInApp = callback
                                    displayOpenEditProfileInApp = true
                                }
                            } else { $0 }
                        }
                    Spacer()
                }
                if let pictureError {
                    Spacer().frame(height: 4)
                    pictureError.textView
                        .font(theme.fonts.caption2)
                        .bold()
                        .foregroundColor(theme.colors.error)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer().frame(height: 30)
                OctopusTextInput(
                    text: $nickname, label: "Profile.Edit.Nickname.Description",
                    placeholder: "Profile.Nickname.Placeholder",
                    hint: "Profile.Edit.Nickname.Explanation",
                    error: nicknameError,
                    isFocused: $nicknameFocused,
                    isDisabled: false // visually, let it as it was editable
                )
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .focused($nicknameFocused)
                .disabled(!nicknameEditConfig.fieldIsEditable)
                .overlay(
                    Group {
                        if let callback = nicknameEditConfig.callback {
                            Button(action: {
                                openEditProfileInApp = callback
                                displayOpenEditProfileInApp = true
                            }) {
                                Color.white.opacity(0.0001)
                            }
                            .buttonStyle(.plain)
                        } else {
                            EmptyView()
                        }
                    }
                )
                Spacer().frame(height: 24)
                OctopusTextInput(
                    text: $bio,
                    label: "Profile.Edit.Bio.Description",
                    placeholder: "Profile.Edit.Bio.Placeholder",
                    error: bioError,
                    lineLimitRange: 8...,
                    isFocused: $bioFocused,
                    isDisabled: false) // visually, let it as it was editable
                .focused($bioFocused)
                .onValueChanged(of: bio) { [oldValue = bio] newValue in
                    // only scroll to bottom if the last line changed
                    let previousLastLine = oldValue.components(separatedBy: "\n").last ?? ""
                    let newLastLine = newValue.components(separatedBy: "\n").last ?? ""
                    if previousLastLine != newLastLine {
                        withAnimation {
                            scrollToBottomOfId = "bioBlockBottom"
                        }
                    }
                }
                .disabled(!bioEditConfig.fieldIsEditable)
                .overlay(
                    Group {
                        if let callback = bioEditConfig.callback {
                            Button(action: {
                                nicknameFocused = false
                                bioFocused = false
                                openEditProfileInApp = callback
                                displayOpenEditProfileInApp = true
                            }) {
                                Color.white.opacity(0.0001)
                            }
                            .buttonStyle(.plain)
                        } else {
                            EmptyView()
                        }
                    }
                )
                // Not passed as an hint because it is a String and aligned right
                if bioError == nil, bioEditConfig.fieldIsEditable {
                    Spacer().frame(height: 2)
                    Text(verbatim: "\(bio.count)/\(bioMaxLength)")
                        .font(theme.fonts.caption2)
                        .foregroundColor(bio.count <= bioMaxLength ? theme.colors.gray700 : theme.colors.error)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                Color.clear.frame(height: 1)
                    .id("bioBlockBottom")
                Spacer().frame(height: 7)
                Spacer()
            }
            .padding(.top)
            .padding(.horizontal, 20)
            .compatAlert(
                "Profile.Edit.ClientApp.Alert.Title",
                isPresented: $displayOpenEditProfileInApp,
                presenting: openEditProfileInApp,
                actions: { openEditProfileInApp in
                    Button(action: openEditProfileInApp) {
                        Text("Common.Ok", bundle: .module)
                    }
                    Button(action: {}) {
                        Text("Common.Cancel", bundle: .module)
                    }
                },
                message: { _ in })
        }
    }
}

private struct PictureView: View {
    @Environment(\.octopusTheme) private var theme
    @Binding var picture: EditProfileViewModel.Picture
    let nickname: String
    let pictureSize: CGFloat

    @State private var selectedItems: [ImageAndData] = []
    @State private var imagePickingError: Error?
    @State private var loading = false
    @State private var openActionList = false
    @State private var openPhotosPicker = false

    init(picture: Binding<EditProfileViewModel.Picture>, nickname: String, openPhotosPicker: Bool,
         pictureSize: CGFloat) {
        _picture = picture
        self.nickname = nickname
        _openPhotosPicker = .init(initialValue: openPhotosPicker)
        self.pictureSize = pictureSize
    }

    var body: some View {
        if !loading {
            Button(action: {
                if canDeletePicture {
                    openActionList = true
                } else {
                    openPhotosPicker = true
                }
            }) {
                AuthorAvatarView(avatar: authorAvatar)
                    .overlay(
                        Image(res: .editPicture)
                            .foregroundColor(theme.colors.onPrimary)
                            .padding(8)
                            .background(theme.colors.primary)
                            .clipShape(Circle())
                            .frame(width: 28, height: 28)
                            .offset(x: 30, y: 30)
                    )
                    .frame(width: pictureSize, height: pictureSize)
            }
            .buttonStyle(.borderless)
            .actionSheet(isPresented: $openActionList) {
                ActionSheet(title: Text(verbatim: ""), buttons: [
                    ActionSheet.Button.default(Text("Profile.Edit.Picture.Change", bundle: .module)) {
                        openPhotosPicker = true
                    },
                    ActionSheet.Button.destructive(Text("Profile.Edit.Picture.Delete", bundle: .module)) {
                        picture = .deleted
                        selectedItems = []
                    },
                    ActionSheet.Button.cancel()
                ])
            }
            .accessibilityHintInBundle("Accessibility.Profile.Picture.Edit")
            .imagesPicker(isPresented: $openPhotosPicker, selection: $selectedItems, error: $imagePickingError,
                          maxSelectionCount: 1)
            .onValueChanged(of: selectedItems) {
                guard let imagePickerItem = $0.first else {
                    picture = .deleted
                    return
                }
                picture = .changed(imagePickerItem.imageData, imagePickerItem.image)
            }
        } else {
            Compat.ProgressView()
                .frame(width: 60)
        }
    }

    private var authorAvatar: Author.Avatar {
        switch picture {
        case let .unchanged(pictureUrl):
            if let pictureUrl {
                return .image(url: pictureUrl, name: nickname)
            } else {
                return .defaultImage(name: nickname)
            }
        case let .changed(_, image):
            return .localImage(image)
        case .deleted:
            return .defaultImage(name: nickname)
        }
    }

    private var canDeletePicture: Bool {
        switch picture {
        case let .unchanged(url):
            return url != nil
        case .changed:
            return true
        case .deleted:
            return false
        }
    }
}

//#Preview {
//    ContentView(state: .emailEntry(.emailNeeded), sendEmailButtonAvailable: true, email: .constant(""),
//                sendMagicLink: { }, enterNewEmail: { }, checkMagicLinkConfirmed: { })
//}
