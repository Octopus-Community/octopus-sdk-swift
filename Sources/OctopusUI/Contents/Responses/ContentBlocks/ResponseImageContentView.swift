//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import OctopusCore

struct ResponseImageContentView: View {
    @Environment(\.octopusTheme) private var theme

    let image: ImageMedia
    @Binding var zoomableImageInfo: ZoomableImageInfo?

    /// Tells this occurrence of the image apart from another one of the same image on the screen
    @State private var imageOccurrence = UUID()

    private let minAspectRatio: CGFloat = 4 / 5

    var body: some View {
        let source = ZoomableImageSourceID(url: image.url, occurrence: imageOccurrence)
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
                    .frame(maxWidth: .infinity)
                    .zoomableImageSource(source, zoomed: zoomableImageInfo)
                    .modify {
                        if #available(iOS 15.0, *) {
                            $0.overlay {
                                Color.white.opacity(0.0001)
                                    .onTapGesture {
                                        withAnimation {
                                            zoomableImageInfo = .init(
                                                source: source,
                                                image: Image(uiImage: cachedImage.fullSizeImage),
                                                transitionImage: Image(uiImage: cachedImage.ratioImage))
                                        }
                                    }
                            }
                        } else {
                            $0.onTapGesture {
                                withAnimation {
                                    zoomableImageInfo = .init(
                                        source: source,
                                        image: Image(uiImage: cachedImage.fullSizeImage))
                                }
                            }
                        }
                    }
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
