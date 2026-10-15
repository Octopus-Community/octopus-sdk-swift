//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import SwiftUI
import UIKit
import Octopus
import OctopusCore

struct Author: Equatable {
    enum Avatar: Equatable {
        /// The initials of `name` on a color derived from `colorSeed`, or from `name` when there is no seed. A
        /// nickname being typed passes the stored one as seed, so the color does not change with every character.
        /// `community` replaces that computed avatar when the community chose one; it is still "no picture".
        case defaultImage(name: String, colorSeed: String? = nil, community: DefaultAvatar? = nil)
        case image(url: URL, name: String)
        case localImage(UIImage)
        case notConnected
    }
    let profileId: String?
    /// The author's id in the host app's own system (Unified Profile), when the community exposes it.
    /// `nil` for deleted authors, Octopus-auth users, guests and BO/admin-created profiles.
    let clientUserId: String?
    let avatar: Avatar
    let name: DisplayableString
    let tags: ProfileTags
    let gamificationLevel: GamificationLevel?

    init(profile: MinimalProfile?, gamificationLevel: GamificationLevel?) {
        guard let profile else {
            profileId = nil
            clientUserId = nil
            name = .localizationKey("Author.Deleted")
            avatar = .notConnected
            tags = []
            self.gamificationLevel = nil
            return
        }
        profileId = profile.uuid
        clientUserId = profile.clientUserId
        name = .localizedString(profile.nickname)
        avatar = .member(pictureUrl: profile.avatarUrl, name: profile.nickname, community: profile.defaultAvatar)
        tags = profile.tags
        self.gamificationLevel = gamificationLevel
    }
}

extension Author {
    init(profileId: String?,
         clientUserId: String? = nil,
         avatar: Avatar,
         name: DisplayableString,
         tags: ProfileTags,
         gamificationLevel: GamificationLevel?) {
        self.profileId = profileId
        self.clientUserId = clientUserId
        self.avatar = avatar
        self.name = name
        self.tags = tags
        self.gamificationLevel = gamificationLevel
    }
}

extension Author.Avatar {
    /// The avatar of a member: their picture, else the default the community chose for them, else the computed one.
    static func member(pictureUrl: URL?, name: String, community: DefaultAvatar?) -> Author.Avatar {
        if let pictureUrl { return .image(url: pictureUrl, name: name) }
        return .defaultImage(name: name, community: community)
    }

    /// The avatar of a nickname being typed: its initials on the color of `colorSeed` (the stored nickname), or the
    /// community's default, or the generic silhouette while there is no nickname to take the initials from.
    static func typing(nickname: String, colorSeed: String?, community: DefaultAvatar? = nil) -> Author.Avatar {
        nickname.isEmpty ? .notConnected : .defaultImage(name: nickname, colorSeed: colorSeed, community: community)
    }

    /// The string the default avatar's color is derived from.
    static func colorSource(name: String, colorSeed: String?) -> String {
        colorSeed?.nilIfEmpty ?? name
    }
}

extension Author {
    /// Whether the viewing user is allowed to block this author client-side.
    /// Returns `false` for deleted authors (no profileId), admin authors, and the current user themself.
    /// Kept in step with the other UI-side gate, `DisplayableProfile.canBeBlocked`.
    func canBeBlocked(currentUserId: String?) -> Bool {
        guard let profileId else { return false }
        if tags.contains(.admin) { return false }
        return profileId != currentUserId
    }
}

struct AuthorAvatarView: View {
    @Environment(\.octopusTheme) private var theme

    let avatar: Author.Avatar?
    @State private var width: CGFloat = 0

    var body: some View {
        Group {
            switch avatar {
            case let .defaultImage(name, colorSeed, community):
                switch community {
                case let .color(backgroundHex, initialsHex)?:
                    initials(of: name,
                             color: UIColor(hex: initialsHex).map { Color($0) } ?? .black,
                             background: UIColor(hex: backgroundHex).map { Color($0) }
                                ?? Author.Avatar.colorSource(name: name, colorSeed: colorSeed).avatarColor)
                case let .image(url)?:
                    remoteImage(url: url, placeholder: .defaultImage(name: name, colorSeed: colorSeed))
                case nil:
                    initials(of: name, color: .black,
                             background: Author.Avatar.colorSource(name: name, colorSeed: colorSeed).avatarColor)
                }
            case let .image(url, name):
                remoteImage(url: url, placeholder: .defaultImage(name: name))
            case let .localImage(image):
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .mask(Circle())
            case .notConnected, .none:
                Image(uiImage: theme.assets.icons.profile.notConnected)
                    .resizable()
                    .scaledToFit()
                    .padding(max(width * 0.24, 4))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        Circle()
                            .foregroundColor(theme.colors.gray200)
                    )
                    .readWidth($width)
            }
        }
        .accessibilityLabelInBundle("Accessibility.Profile.Picture")
    }

    private func initials(of name: String, color: Color, background: Color) -> some View {
        Text(name.initials)
            .bold()
            .lineLimit(1)
            .foregroundColor(color)
            .font(.system(size: 100))
            .minimumScaleFactor(0.01)
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                Circle()
                    .foregroundColor(background)
                    .padding(1)
                    .background(
                        Circle()
                            .fill(theme.colors.gray300)
                    )
            )
    }

    /// A remote image cropped to a circle, `placeholder` drawn while it loads and if it cannot be loaded.
    private func remoteImage(url: URL, placeholder: Author.Avatar) -> some View {
        AsyncCachedImage(url: url, cache: .profile, placeholder: {
            AuthorAvatarView(avatar: placeholder)
        }, content: { cachedImage in
            Image(uiImage: cachedImage.fullSizeImage)
                .resizable()
                .scaledToFill()
        })
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .mask(Circle())
    }
}

#Preview {
    VStack {
        AuthorAvatarView(avatar: .defaultImage(name: "Toto"))
        AuthorAvatarView(avatar: .defaultImage(
            name: "Toto", community: .color(backgroundHex: "#1D3557", initialsHex: "#FFFFFF")))
        AuthorAvatarView(avatar: .defaultImage(
            name: "Toto", community: .color(backgroundHex: "#F1FAEE", initialsHex: "#000000")))
        // The URL does not resolve: shows the loading / failure fallback (computed color and initials).
        AuthorAvatarView(avatar: .defaultImage(
            name: "Toto", community: .image(url: URL(string: "https://invalid.example/a.jpg")!)))
    }
    .frame(width: 60)
}
