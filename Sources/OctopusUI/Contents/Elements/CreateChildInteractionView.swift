//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit

struct CreateChildInteractionView: View {
    @Environment(\.octopusTheme) private var theme

    enum Kind {
        case comment
        case reply
    }

    /// What follows the icon.
    enum Caption {
        /// "Comment" or "Reply": the comment and reply footers.
        case label(LocalizedStringKey)
        /// The number of comments, hidden at 0: the post footer.
        case count(Int)
    }

    @Environment(\.locale) private var locale

    let image: UIImage
    let caption: Caption
    let kind: Kind

    @Compat.ScaledMetric(relativeTo: .caption1) private var imageSize: CGFloat = 24

    private var normalFont: Font { theme.fonts.caption1 }

    init(image: UIImage, text: LocalizedStringKey, kind: Kind) {
        self.init(image: image, caption: .label(text), kind: kind)
    }

    init(image: UIImage, caption: Caption, kind: Kind) {
        self.image = image
        self.caption = caption
        self.kind = kind
    }

    private var spacing: CGFloat {
        switch caption {
        case .label: 4
        case .count: 6
        }
    }

    var body: some View {
        HStack(spacing: spacing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: imageSize, height: imageSize)
                // No bounce here, unlike the like button: the icon is the theme's and never changes on a tap, so no
                // member action can trigger one. A bounce tied to the image only ever fired without one, as when
                // the app came back to the foreground.
                .accessibilityHidden(true)

            switch caption {
            case let .label(text):
                Text(text, bundle: .module)
                    .fontWeight(.medium)
            case let .count(count):
                if count > 0 {
                    Text(String.formattedCount(count, locale: locale))
                        .fontWeight(.medium)
                }
            }
        }
        .foregroundColor(theme.colors.gray700)
        .font(normalFont)
    }
}
