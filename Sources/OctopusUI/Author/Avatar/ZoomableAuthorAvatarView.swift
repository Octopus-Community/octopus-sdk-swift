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
            zoomableImage(url: url, placeholder: .defaultImage(name: name))
        case let .defaultImage(name, colorSeed, .image(url)?):
            // Not the member's picture, but drawn like one: it zooms like one.
            zoomableImage(url: url, placeholder: .defaultImage(name: name, colorSeed: colorSeed))
        default:
            AuthorAvatarView(avatar: avatar)
        }
    }

    private func zoomableImage(url: URL, placeholder: Author.Avatar) -> some View {
        AsyncCachedImage(url: url, cache: .profile, placeholder: {
            AuthorAvatarView(avatar: placeholder)
        }, content: { cachedImage in
            Image(uiImage: cachedImage.fullSizeImage)
                .resizable()
                .scaledToFill()
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
    }
}
