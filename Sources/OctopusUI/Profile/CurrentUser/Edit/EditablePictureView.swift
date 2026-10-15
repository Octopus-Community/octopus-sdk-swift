//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import OctopusCore

/// The profile picture with its edit badge: a tap picks a new picture, or offers to change or delete the current
/// one. Shared by the profile editor and the nickname choice screen.
struct EditablePictureView: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.layoutDirection) private var layoutDirection
    @Binding var picture: EditProfileViewModel.Picture
    let nickname: String
    /// Where the default avatar takes its color from: the stored nickname, so it stays put while the nickname is typed.
    let avatarColorSeed: String?
    /// The default the community chose for the member, drawn while they have no picture.
    let communityAvatar: DefaultAvatar?
    let pictureSize: CGFloat

    @State private var selectedItems: [ImageAndData] = []
    @State private var imagePickingError: Error?
    @State private var loading = false
    @State private var openActionList = false
    @State private var openPhotosPicker = false

    init(picture: Binding<EditProfileViewModel.Picture>, nickname: String, avatarColorSeed: String?,
         communityAvatar: DefaultAvatar?, openPhotosPicker: Bool, pictureSize: CGFloat) {
        _picture = picture
        self.nickname = nickname
        self.avatarColorSeed = avatarColorSeed
        self.communityAvatar = communityAvatar
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
                        Image(uiImage: theme.assets.icons.profile.editPicture)
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(theme.colors.onPrimary)
                            .padding(8)
                            .background(theme.colors.primary)
                            .clipShape(Circle())
                            .frame(width: 28, height: 28)
                            // Keep the badge on the avatar's trailing-bottom corner in both directions
                            // (offset x is physical, so flip it in RTL).
                            .offset(x: layoutDirection == .rightToLeft ? -30 : 30, y: 30)
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
                return defaultAvatar
            }
        case let .changed(_, image):
            return .localImage(image)
        case .deleted:
            return defaultAvatar
        }
    }

    private var defaultAvatar: Author.Avatar {
        .typing(nickname: nickname, colorSeed: avatarColorSeed, community: communityAvatar)
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
