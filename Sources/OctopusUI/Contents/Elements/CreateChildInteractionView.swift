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

    let image: UIImage
    let text: LocalizedStringKey
    let kind: Kind

    @Compat.ScaledMetric(relativeTo: .caption1) private var imageSize: CGFloat = 24

    private var normalFont: Font { theme.fonts.caption1 }

    init(image: UIImage, text: LocalizedStringKey, kind: Kind) {
        self.image = image
        self.text = text
        self.kind = kind
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: imageSize, height: imageSize)
                // No bounce here, unlike the like button: the icon is the theme's and never changes on a tap, so no
                // member action can trigger one. A bounce tied to the image only ever fired without one, as when
                // the app came back to the foreground.
                .accessibilityHidden(true)

            Text(text, bundle: .module)
                .fontWeight(.medium)
        }
        .foregroundColor(theme.colors.gray700)
        .font(normalFont)
    }
}
