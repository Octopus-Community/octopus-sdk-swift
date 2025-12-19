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
    let tags: ProfileTags
    let gamificationLevel: GamificationLevel?

    init(profile: MinimalProfile?, gamificationLevel: GamificationLevel?) {
        guard let profile else {
            profileId = nil
            name = .localizationKey("Author.Deleted")
            avatar = .notConnected
            tags = []
            self.gamificationLevel = nil
            return
        }
        profileId = profile.uuid
        name = .localizedString(profile.nickname)
        if let avatarUrl = profile.avatarUrl {
            avatar = .image(url: avatarUrl, name: profile.nickname)
        } else {
            avatar = .defaultImage(name: profile.nickname)
        }
        tags = profile.tags
        self.gamificationLevel = gamificationLevel
    }
}

struct AuthorAvatarView: View {
    @Environment(\.octopusTheme) private var theme

    let avatar: Author.Avatar?
    @State private var width: CGFloat = 0

    var body: some View {
        Group {
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
                            .padding(1)
                            .background(
                                Circle()
                                    .fill(theme.colors.gray300)
                            )
                    )
            case let .image(url, name):
                AsyncCachedImage(url: url, cache: .profile, placeholder: {
                    AuthorAvatarView(avatar: .defaultImage(name: name))
                }, content: { cachedImage in
                    Image(uiImage: cachedImage.fullSizeImage)
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
        .accessibilityLabelInBundle("Accessibility.Profile.Picture")
    }
}

#Preview {
    AuthorAvatarView(avatar: .defaultImage(name: "Toto"))
//    AuthorAvatarView(avatar: .defaultImage(name: ""))
//    AuthorAvatarView(avatar: .defaultImage(name: "Test"))
}
