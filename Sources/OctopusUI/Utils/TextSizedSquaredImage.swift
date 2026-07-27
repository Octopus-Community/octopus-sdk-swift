//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct IconImage: View {
    let image: UIImage
    /// Mirror the icon horizontally in a right-to-left layout. Enable it for *directional* glyphs
    /// (chevrons, arrows): a `UIImage` rendered via SwiftUI's `Image(uiImage:)` does not inherit the
    /// asset catalog's RTL auto-mirroring, so it must be requested explicitly. Leave `false` for
    /// symmetrical icons (close, ellipsis, …).
    let flipsForRTL: Bool
    /// Explicit square side in points. When `nil` (default), the icon matches the current font's
    /// line height (inline-with-text sizing). When set, the icon is rendered at that fixed side.
    let size: CGFloat?

    @State private var lineHeight: CGFloat = 24

    init(_ image: UIImage, size: CGFloat? = nil, flipsForRTL: Bool = false) {
        self.image = image
        self.size = size
        self.flipsForRTL = flipsForRTL
    }

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .flipsForRightToLeftLayoutDirection(flipsForRTL)
            .scaledToFit()
            .frame(width: size ?? lineHeight, height: size ?? lineHeight)
            .clipped()
            .background(
                Text(verbatim: "x")
                    .fixedSize()
                    .readHeight($lineHeight)
                    .hidden()
            )
    }
}
