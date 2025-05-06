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

    init(octopus: OctopusSDK, bioFocused: Bool = false, photoPickerFocused: Bool = false) {
        _viewModel = Compat.StateObject(wrappedValue: EditProfileViewModel(octopus: octopus))
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
        .navigationBarBackButtonHidden()
        .navigationBarTitle(Text("Common.Edit", bundle: .module), displayMode: .inline)
        .navigationBarItems(leading: leadingBarItem, trailing: trailingBarItem)
        .alert(
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
                        Button(L10n("Common.Yes"), role: .destructive, action: { presentationMode.wrappedValue.dismiss() })
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
                    .font(theme.fonts.navBarItem)
                    .fontWeight(.semibold)
                    .foregroundColor(viewModel.saveAvailable ? theme.colors.primary : theme.colors.disabled)
            }
            .disabled(!viewModel.saveAvailable)
        } else {
            if #available(iOS 14.0, *) {
                ProgressView()
            } else {
                Button(action: viewModel.updateProfile) {
                    Text("Common.Save", bundle: .module)
                        .font(theme.fonts.navBarItem)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.colors.disabled)
                }
                .disabled(true)
            }
        }
    }

    private var leadingBarItem: some View {
        Button(action: {
            if viewModel.hasChanges {
                showChangesWillBeLostAlert = true
            } else {
                presentationMode.wrappedValue.dismiss()
            }
        }) {
            Image(systemName: "chevron.left")
                .font(theme.fonts.navBarItem.weight(.semibold))
                .contentShape(Rectangle())
                .padding(.trailing, 20)
        }
        .padding(.leading, -8)
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
        EditProfileFormView(
            nicknameEditConfig: nicknameEditConfig,
            bioEditConfig: bioEditConfig,
            pictureEditConfig: pictureEditConfig,
            nickname: $nickname, bio: $bio, picture: $picture, nicknameForAvatar: nicknameForAvatar,
            nicknameError: nicknameError, bioError: bioError, pictureError: pictureError,
            bioFocused: bioFocused, bioMaxLength: bioMaxLength, photoPickerFocused: photoPickerFocused)
        .disabled(isLoading)
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
                    PictureView(picture: $picture, nickname: nicknameForAvatar, openPhotosPicker: photoPickerFocused)
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
                Text("Profile.Edit.Nickname.Description", bundle: .module)
                    .font(theme.fonts.body2)
                    .fontWeight(.medium)
                    .foregroundColor(theme.colors.gray700)
                    .multilineTextAlignment(.center)
                Spacer().frame(height: 6)
                TextField(L10n("Profile.Nickname.Placeholder"), text: $nickname)
                    .font(theme.fonts.body2)
                    .foregroundColor(theme.colors.gray900)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 8)
                    .focused($nicknameFocused)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(nicknameFocused ? theme.colors.gray900 : theme.colors.gray300,
                                    lineWidth: nicknameFocused ? 2 : 1)
                    )
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
                Spacer().frame(height: 6)
                Text("Profile.Edit.Nickname.Explanation", bundle: .module)
                    .font(theme.fonts.caption1)
                    .foregroundColor(theme.colors.gray500)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let nicknameError {
                    Spacer().frame(height: 4)
                    nicknameError.textView
                        .font(theme.fonts.caption2)
                        .bold()
                        .foregroundColor(theme.colors.error)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer().frame(height: 20)
                HStack {
                    Text("Profile.Edit.Bio.Description", bundle: .module)
                        .font(theme.fonts.body2)
                        .fontWeight(.medium)
                        .foregroundColor(theme.colors.gray700)
                        .multilineTextAlignment(.center)
                    Spacer()
                    if bioEditConfig.fieldIsEditable {
                        Text(verbatim: "(\(bio.count)/\(bioMaxLength))")
                            .font(theme.fonts.body2)
                            .foregroundColor(bio.count <= bioMaxLength ? theme.colors.gray500 : theme.colors.error)
                    }
                }
                Spacer().frame(height: 6)
                MultilineTextField(text: $bio, shouldFocus: $bioFocused, placeholderText: "Profile.Edit.Bio.Placeholder")
                    .font(theme.fonts.body2)
                    .foregroundColor(theme.colors.gray900)
                    .focused($bioFocused)
                    .frame(minHeight: 140, alignment: .top)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 8)
                    .background(Color(UIColor.systemBackground))
                    .onTapGesture {
                        bioFocused = true
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(bioFocused ? theme.colors.gray900 : theme.colors.gray300,
                                    lineWidth: bioFocused ? 2 : 1)
                    )
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
                if let bioError {
                    Spacer().frame(height: 4)
                    bioError.textView
                        .font(theme.fonts.caption2)
                        .bold()
                        .foregroundColor(theme.colors.error)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Color.clear.frame(height: 1)
                    .id("bioBlockBottom")
                Spacer().frame(height: 7)
                Spacer()
            }
            .padding(.top)
            .padding(.horizontal, 20)
            .alert(
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

struct MultilineTextField: View {
    @Environment(\.octopusTheme) private var theme
    @Binding var text: String
    @Binding var shouldFocus: Bool
    let placeholderText: LocalizedStringKey?

    private let focusInterested: Bool

    init(text: Binding<String>, shouldFocus: Binding<Bool>? = nil, placeholderText: LocalizedStringKey? = nil) {
        self._text = text
        self._shouldFocus = shouldFocus ?? .constant(false)
        focusInterested = shouldFocus != nil
        self.placeholderText = placeholderText
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 16.0, *) {
            TextField(String(""), text: $text, axis: .vertical)
                .placeholder(when: text.isEmpty) {
                    if let placeholderText {
                        Text(placeholderText, bundle: .module)
                            .foregroundColor(theme.colors.gray500)
                    } else {
                        EmptyView()
                    }
                }
                .multilineTextAlignment(.leading)
        } else {
            // TODO: create a TextField that expands vertically on iOS 13
            TextField(String(""), text: $text)
                .placeholder(when: text.isEmpty) {
                    if let placeholderText {
                        Text(placeholderText, bundle: .module)
                            .foregroundColor(theme.colors.gray500)
                    } else {
                        EmptyView()
                    }
                }
                .multilineTextAlignment(.leading)
        }
    }
}

private struct PictureView: View {
    @Environment(\.octopusTheme) private var theme
    @Binding var picture: EditProfileViewModel.Picture
    let nickname: String

    @State private var selectedItems: [ImageAndData] = []
    @State private var imagePickingError: Error?
    @State private var loading = false
    @State private var openActionList = false
    @State private var openPhotosPicker = false

    init(picture: Binding<EditProfileViewModel.Picture>, nickname: String, openPhotosPicker: Bool) {
        _picture = picture
        self.nickname = nickname
        _openPhotosPicker = .init(initialValue: openPhotosPicker)
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
                        Image(.editPicture)
                            .foregroundColor(theme.colors.onPrimary)
                            .padding(8)
                            .background(theme.colors.primary)
                            .clipShape(Circle())
                            .frame(width: 28, height: 28)
                            .offset(x: 30, y: 30)
                    )
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
