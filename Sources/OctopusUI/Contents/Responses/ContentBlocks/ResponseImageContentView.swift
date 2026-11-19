//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import OctopusCore

struct ResponseImageContentView: View {
    @Environment(\.octopusTheme) private var theme

    let image: ImageMedia
    @Binding var zoomableImageInfo: ZoomableImageInfo?

    @State private var sourceGeometry = FullscreenViewerSourceGeometry()

    private let minAspectRatio: CGFloat = 4 / 5

    var body: some View {
        AsyncCachedImage(
            url: image.url, cache: .content,
            croppingRatio: minAspectRatio,
            placeholder: {
                theme.colors.gray300
                    .aspectRatio(
                        max(image.size.width / image.size.height, minAspectRatio),
                        contentMode: .fit)
                    .clipped()
            },
            content: { cachedImage in
                Image(uiImage: cachedImage.ratioImage)
                    .resizable()
                    .scaledToFit()
                    // The image closes the card: its bottom corners are the rounded ones of `ResponseCardView`.
                    .inPlacePinchZoom(image: cachedImage.ratioImage, cornerRadius: 8, roundedCorners: .bottomCorners)
                    .frame(maxWidth: .infinity)
                    .fullscreenViewerSource(
                        sourceGeometry,
                        isInViewer: zoomableImageInfo?.isOpened(from: sourceGeometry, showing: [image.url]) ?? false)
                    // put the tap in an overlay because it seems that the image touch area is not clipped. Hence,
                    // it takes the tap over the text. When put in an overlay, it seems to work correctly
                    .overlay(
                        Color.white.opacity(0.0001)
                            .onTapGesture {
                                let sourceGeometry = sourceGeometry
                                zoomableImageInfo = .single(
                                    url: image.url, cachedImage: cachedImage, source: sourceGeometry,
                                    sourceFrame: { sourceGeometry.frame })
                            }
                    )
            }
        )
        .modify {
            if #unavailable(iOS 17.0) {
                $0.fixedSize(horizontal: false, vertical: true)
            } else { $0 }
        }
        // Design spec `pt-[2px]` — a small breathing strip above the image separating it from the
        // text block. The image is still flush with the card's bottom edge (no bottom padding).
        .padding(.top, 2)
    }
}
