//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct ZoomableAuthorAvatarView: View {
    @Environment(\.octopusTheme) private var theme

    let avatar: Author.Avatar?
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    @State private var sourceGeometry = FullscreenViewerSourceGeometry()

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
                .onTapGesture {
                    let sourceGeometry = sourceGeometry
                    zoomableImageInfo = Self.zoomableImageInfo(
                        url: url, image: cachedImage.fullSizeImage, source: sourceGeometry,
                        frame: { sourceGeometry.frame })
                }
        })
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .mask(Circle())
        .fullscreenViewerSource(
            sourceGeometry, isInViewer: zoomableImageInfo?.isOpened(from: sourceGeometry, showing: [url]) ?? false)
        .accessibilityLabelInBundle("Accessibility.Profile.Picture")
    }

    /// The request for the picture, flying from the circle it is drawn in: the largest one centred in its frame.
    ///
    /// - Parameters:
    ///   - source: the picture, hidden while the viewer is open.
    ///   - frame: the frame of the picture, read now for the flight to the viewer, and again when the viewer closes,
    ///     for the flight back.
    @MainActor
    static func zoomableImageInfo(url: URL, image: UIImage, source: FullscreenViewerSourceGeometry,
                                  frame: @escaping @MainActor () -> CGRect?) -> ZoomableImageInfo {
        let circle = Self.circle(in: frame())
        return ZoomableImageInfo(
            // The picture is drawn whole, filling its circle: there is no cropped image to fly with.
            items: [.init(url: url, image: image, transitionImage: nil)],
            index: 0,
            source: ObjectIdentifier(source),
            // Read by VoiceOver in the viewer, as on the profile.
            accessibilityLabelKey: "Accessibility.Profile.Picture",
            sourceFrame: circle,
            sourceCornerRadius: (circle?.width ?? 0) / 2,
            liveSourceFrame: { Self.circle(in: frame()) })
    }

    private static func circle(in frame: CGRect?) -> CGRect? {
        frame.map { frame in
            let side = min(frame.width, frame.height)
            return CGRect(x: frame.midX - side / 2, y: frame.midY - side / 2, width: side, height: side)
        }
    }
}
