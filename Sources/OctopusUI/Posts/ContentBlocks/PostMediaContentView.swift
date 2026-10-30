//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import OctopusCore

struct PostMediaContentView: View {
    @Environment(\.octopusTheme) private var theme
    @EnvironmentObject private var videoManager: VideoManager

    let postId: String
    let width: CGFloat
    let media: PostAttachmentsViewData.Media
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    /// Visibility payload attached to the video's bounds anchor so `postsVisibilityScrollView`
    /// can detect when the video is centered and auto-play it. `nil` disables the anchor
    /// (e.g. standalone previews).
    let visiblePost: VisiblePost?

    /// Tells this occurrence of the image apart from another one of the same image on the screen
    @State private var imageOccurrence = UUID()

    private let minAspectRatio: CGFloat = 4 / 5

    var body: some View {
        switch media {
        case let .image(image):
            imageView(image)
        case let .video(video):
            videoView(video)
        }
    }

    @ViewBuilder
    private func imageView(_ image: ImageMedia) -> some View {
        let source = ZoomableImageSourceID(url: image.url, occurrence: imageOccurrence)
        AsyncCachedImage(
            url: image.url, cache: .content,
            croppingRatio: minAspectRatio,
            placeholder: {
                theme.colors.gray200
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
                            // put the tap in an overlay because it seems that the image touch area is not
                            // clipped. Hence, it takes the tap over the text. When put in an overlay, it seems
                            // to work correctly
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
    }

    @ViewBuilder
    private func videoView(_ video: VideoMedia) -> some View {
        VideoPlayerView(
            videoManager: videoManager,
            videoMedia: video,
            contentId: postId,
            width: width)
            .aspectRatio(video.size.width / video.size.height, contentMode: .fit)
            .modify { view in
                if let visiblePost {
                    view.anchorPreference(
                        key: VisibleItemsPreference<VisiblePost>.self,
                        value: .bounds
                    ) { anchor in
                        [.init(item: visiblePost, bounds: anchor)]
                    }
                } else {
                    view
                }
            }
    }
}

#Preview("Image") {
    PostMediaContentView(
        postId: "p1", width: 393,
        media: .image(ImageMedia(
            url: URL(string: "https://picsum.photos/700/750")!,
            size: CGSize(width: 700, height: 750))),
        zoomableImageInfo: .constant(nil),
        visiblePost: nil)
    .mockEnvironmentForPreviews()
    // Video case requires VideoManager environment object — covered in PostView integration preview.
}
