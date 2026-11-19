//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import ImageIO
import SwiftUI

/// The images of the post being written, as square thumbnails in a horizontal strip. Each thumbnail has a
/// button that removes it, and the last one carries the « Add » pill that opens the picker again while the post
/// can take another image: there is no separate tile for it.
///
/// The strip spans the whole width of the composer: it starts aligned with the rest of the form, then scrolls
/// under the trailing margin.
struct CreatePostImagesStrip: View {
    @Environment(\.octopusTheme) private var theme
    @Compat.ScaledMetric(relativeTo: .caption1) private var addMoreIconSize: CGFloat = Dimensions.addMoreIconSize

    let images: [ImageAndData]
    /// Whether the last thumbnail carries the « Add » pill (`CreatePostAttachmentRules.showsAddMorePill`).
    let showsAddMorePill: Bool
    /// The horizontal margin of the composer, which the strip bleeds through so it scrolls up to the screen edge.
    let horizontalMargin: CGFloat
    /// The id (`ImageAndData.thumbnailId`) of a thumbnail to scroll to, reset to `nil` once taken into account.
    @Binding var pictureToReveal: String?
    let deleteImage: (Int) -> Void
    let addMoreImages: () -> Void

    /// The image count the strip last displayed, to tell a growth from a deletion.
    @State private var displayedImageCount: Int
    @State private var scrollRequest: Compat.ScrollRequest?

    init(images: [ImageAndData], showsAddMorePill: Bool, horizontalMargin: CGFloat,
         pictureToReveal: Binding<String?> = .constant(nil),
         deleteImage: @escaping (Int) -> Void, addMoreImages: @escaping () -> Void) {
        self.images = images
        self.showsAddMorePill = showsAddMorePill
        self.horizontalMargin = horizontalMargin
        self._pictureToReveal = pictureToReveal
        self.deleteImage = deleteImage
        self.addMoreImages = addMoreImages
        // Seeded with the images the strip is created with, so prefilled ones (or the first pick, which
        // creates the strip) do not scroll: the strip starts at its beginning.
        _displayedImageCount = State(initialValue: images.count)
    }

    var body: some View {
        // Not scrolled to its extremities, which adds spacer views around the thumbnails, and bouncing even when
        // its thumbnails fit, like a plain scroll view. The fixed height keeps the strip at its thumbnails' height
        // on iOS 13 and 14, where the compat scroll view lays out in a `GeometryReader`, which would otherwise
        // take the height the form proposes.
        Compat.ScrollView(.horizontal, showIndicators: false, scrollRequest: $scrollRequest,
                          preventScrollIfContentFits: false, canScrollToExtremities: false) {
            HStack(spacing: Dimensions.spacing) {
                // Each pick decodes its own `UIImage`, so its instance identifies a thumbnail even when the same
                // photo is picked twice, and keeps it across deletions of the ones before it.
                ForEach(Array(images.enumerated()), id: \.element.thumbnailId) { index, imageAndData in
                    thumbnail(imageAndData, index: index)
                }
            }
            .padding(.horizontal, horizontalMargin)
        }
        .frame(height: Dimensions.thumbnailSide)
        .padding(.horizontal, -horizontalMargin)
        .onValueChanged(of: images.count) { newCount in
            // Compared first: below iOS 14 this runs on every render, and the requests are ignored there anyway.
            guard newCount != displayedImageCount else { return }
            let shouldScroll = Self.shouldScrollToLast(from: displayedImageCount, to: newCount)
            displayedImageCount = newCount
            guard shouldScroll, let lastId = images.last?.thumbnailId else { return }
            // Hops to the next main-queue turn so the new thumbnails are laid out first.
            DispatchQueue.main.async {
                scrollRequest = Compat.ScrollRequest(id: lastId, anchor: .trailing)
            }
        }
        .onValueChanged(of: pictureToReveal, initial: true, onChange: reveal)
    }

    /// Scrolls to the thumbnail to reveal, centered, then clears the request so the same one can be made again.
    private func reveal(_ id: String?) {
        guard let id else { return }
        pictureToReveal = nil
        // Same hop as for the added photos, so the thumbnails are laid out first.
        DispatchQueue.main.async {
            scrollRequest = Compat.ScrollRequest(id: id, anchor: .center)
        }
    }

    /// Whether the strip scrolls to its last thumbnail when its image count changes: only when photos were
    /// added, so that removing one does not move it.
    static func shouldScrollToLast(from previousCount: Int, to newCount: Int) -> Bool {
        newCount > previousCount
    }

    private func thumbnail(_ imageAndData: ImageAndData, index: Int) -> some View {
        Thumbnail(imageAndData: imageAndData, side: Dimensions.thumbnailSide)
            .clipShape(RoundedRectangle(cornerRadius: Dimensions.cornerRadius))
            .overlay(deleteButton(index: index), alignment: .topTrailing)
            .overlay(addMorePill(isLast: index == images.count - 1), alignment: .bottomTrailing)
    }

    private func deleteButton(index: Int) -> some View {
        Button(action: { deleteImage(index) }) {
            IconImage(theme.assets.icons.content.post.creation.deletePicture)
                .font(theme.fonts.caption1)
                .foregroundColor(Dimensions.overlayForeground)
                .padding(Dimensions.deleteIconPadding)
                .background(Circle().foregroundColor(Dimensions.overlayBackground))
                // Keeps a 44pt tap target around the small visible circle.
                .padding(Dimensions.overlayInset)
                .frame(minWidth: 44, minHeight: 44, alignment: .topTrailing)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabelInBundle("Accessibility.Image.Delete")
    }

    /// The pill that opens the picker again, laid on the last thumbnail. Its text is what VoiceOver reads.
    @ViewBuilder
    private func addMorePill(isLast: Bool) -> some View {
        if isLast && showsAddMorePill {
            Button(action: addMoreImages) {
                HStack(spacing: Dimensions.addMoreSpacing) {
                    IconImage(theme.assets.icons.content.post.creation.addPicture, size: addMoreIconSize)
                        .accessibilityHidden(true)
                    Text("Content.Create.AddMorePictures", bundle: .module)
                        .lineLimit(1)
                }
                .font(theme.fonts.caption1)
                .foregroundColor(Dimensions.overlayForeground)
                .padding(.leading, Dimensions.addMoreLeadingPadding)
                .padding(.trailing, Dimensions.addMoreTrailingPadding)
                .padding(.vertical, Dimensions.addMoreVerticalPadding)
                .background(Capsule().foregroundColor(Dimensions.overlayBackground))
                // Keeps a 44pt tap target around the 32pt pill.
                .padding(Dimensions.overlayInset)
                .frame(minHeight: 44, alignment: .bottomTrailing)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

/// A square thumbnail of a picked image, decoded at the size it is shown: a photo from the library can weigh
/// tens of megapixels, and the strip holds up to `Validators.Post.maxImageCount` of them.
private struct Thumbnail: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.displayScale) private var displayScale

    let imageAndData: ImageAndData
    let side: CGFloat

    @State private var thumbnail: UIImage?

    var body: some View {
        Group {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                theme.colors.gray200
            }
        }
        .frame(width: side, height: side)
        .clipped()
        .onAppear {
            guard thumbnail == nil else { return }
            let imageAndData = imageAndData
            let maxPixelSize = ImageThumbnail.maxPixelSize(filling: side * displayScale,
                                                           imageSize: imageAndData.image.size)
            Task {
                let downsampled = await Task.detached(priority: .userInitiated) {
                    ImageThumbnail.downsample(imageAndData.imageData, maxPixelSize: maxPixelSize)
                }.value
                thumbnail = downsampled ?? imageAndData.image
            }
        }
    }
}

/// Decodes an image at a reduced size, without decoding it at full size first.
enum ImageThumbnail {
    /// The longest side, in pixels, that lets an image of `imageSize` fill a square of `squareSide` pixels:
    /// its shortest side must reach the square's side.
    static func maxPixelSize(filling squareSide: CGFloat, imageSize: CGSize) -> CGFloat {
        let shortSide = min(imageSize.width, imageSize.height)
        let longSide = max(imageSize.width, imageSize.height)
        guard shortSide > 0 else { return squareSide }
        return (squareSide * longSide / shortSide).rounded(.up)
    }

    /// The image of `data`, its longest side reduced to `maxPixelSize` (never enlarged) and its orientation
    /// applied. `nil` when the data is not an image.
    static func downsample(_ data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

extension ImageAndData {
    /// A `String`, as the compat scroll view scrolls to string ids.
    var thumbnailId: String { String(UInt(bitPattern: ObjectIdentifier(image))) }
}

private extension CreatePostImagesStrip {
    /// Measured on the composer design (one point per pixel of its 393pt-wide screens).
    enum Dimensions {
        static let thumbnailSide: CGFloat = 220
        static let spacing: CGFloat = 10
        static let cornerRadius: CGFloat = 8
        /// The inset of the delete button and of the « Add » pill from the edges of the thumbnail.
        static let overlayInset: CGFloat = 8
        static let deleteIconPadding: CGFloat = 6
        /// The « Add » pill is 32pt high. Its icon leaves a transparent margin around the glyph (2pt at this
        /// size), so the leading padding is shorter than the trailing one: the glyph and the text both sit about
        /// 12pt from the edges of the pill.
        static let addMoreIconSize: CGFloat = 20
        static let addMoreLeadingPadding: CGFloat = 10
        static let addMoreTrailingPadding: CGFloat = 12
        static let addMoreVerticalPadding: CGFloat = 6
        static let addMoreSpacing: CGFloat = 4
        /// The overlays sit over a photo, not over the screen background, so they keep the same colors in both
        /// color schemes: the light gray900 (#141414) at 75 % opacity, with a white glyph and text. The theme's
        /// gray900 cannot be used, as it turns white in dark mode.
        static let overlayBackground = Color(red: 0x14 / 255, green: 0x14 / 255, blue: 0x14 / 255).opacity(0.75)
        static let overlayForeground = Color.white
    }
}

#Preview {
    CreatePostImagesStrip(
        images: [ImageAndData(imageData: Data(), image: .actions), ImageAndData(imageData: Data(), image: .add)],
        showsAddMorePill: true, horizontalMargin: 16, deleteImage: { _ in }, addMoreImages: { })
}
