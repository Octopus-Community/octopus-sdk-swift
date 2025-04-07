//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import SwiftUI
import UIKit
import Octopus
import OctopusCore

struct Author: Equatable {
    enum Avatar: Equatable {
        case defaultImage(name: String)
        case image(url: URL, name: String)
        case localImage(UIImage)
        case notConnected
    }
    let profileId: String?
    let avatar: Avatar
    let name: DisplayableString

    init(profile: MinimalProfile?) {
        guard let profile else {
            profileId = nil
            name = .localizationKey("Author.Deleted")
            avatar = .notConnected
            return
        }
        profileId = profile.uuid
        name = .localizedString(profile.nickname)
        if let avatarUrl = profile.avatarUrl {
            avatar = .image(url: avatarUrl, name: profile.nickname)
        } else {
            avatar = .defaultImage(name: profile.nickname)
        }
    }

    init(avatar: Avatar, name: String, profileId: String) {
        self.profileId = profileId
        self.avatar = avatar
        self.name = .localizedString(name)
    }
}

struct AuthorAvatarView: View {
    @Environment(\.octopusTheme) private var theme

    let avatar: Author.Avatar?
    @State private var width: CGFloat = 0

    var body: some View {
        switch avatar {
        case let .defaultImage(name):
            Text(name.initials)
                .bold()
                .lineLimit(1)
                .foregroundColor(.black)
                .font(.system(size: 100))
                .minimumScaleFactor(0.01)
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    Circle()
                        .foregroundColor(name.avatarColor)
                )
        case let .image(url, name):
            AsyncCachedImage(url: url, cache: .profile, placeholder: {
                Text(name.initials)
                    .bold()
                    .lineLimit(1)
                    .foregroundColor(.black)
                    .font(.system(size: 100))
                    .minimumScaleFactor(0.01)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        Circle()
                            .foregroundColor(name.avatarColor)
                    )
            }, content: { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            })
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .mask(Circle())
        case let .localImage(image):
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .mask(Circle())
        case .notConnected, .none:
            Image(systemName: "person")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(max(width * 0.24, 4))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    Circle()
                        .foregroundColor(theme.colors.gray200)
                )
                .readWidth($width)
        }
    }
}

#Preview {
    AuthorAvatarView(avatar: .defaultImage(name: "Toto"))
//    AuthorAvatarView(avatar: .defaultImage(name: ""))
//    AuthorAvatarView(avatar: .defaultImage(name: "Test"))
}
