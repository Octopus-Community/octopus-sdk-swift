//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct ZoomableAuthorAvatarView: View {
    @Environment(\.octopusTheme) private var theme

    let avatar: Author.Avatar?
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    @State private var width: CGFloat = 0

    var body: some View {
        switch avatar {
        case let .image(url, name):
            AsyncCachedImage(url: url, cache: .profile, placeholder: {
                AuthorAvatarView(avatar: .defaultImage(name: name))
            }, content: { cachedImage in
                Image(uiImage: cachedImage.fullSizeImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .modify {
                        if zoomableImageInfo?.url != url {
                            $0.namespacedMatchedGeometryEffect(id: url, isSource: true)
                        } else {
                            $0
                        }
                    }
                    .onTapGesture {
                        withAnimation {
                            zoomableImageInfo = .init(url: url, image: Image(uiImage: cachedImage.fullSizeImage))
                        }
                    }
            })
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .mask(Circle())
            .accessibilityLabelInBundle("Accessibility.Profile.Picture")
        default:
            AuthorAvatarView(avatar: avatar)
        }
    }
}
