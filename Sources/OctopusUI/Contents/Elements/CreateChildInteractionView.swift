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

    @State private var animate = false
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
                .aspectRatio(contentMode: .fit)
                .frame(width: imageSize, height: imageSize)
                .scaleEffect(animate ? 1.4 : 1.0)
                .opacity(animate ? 0.9 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.3), value: animate)
                .accessibilityHidden(true)

            Text(text, bundle: .module)
                .fontWeight(.medium)
        }
        .foregroundColor(theme.colors.gray700)
        .font(normalFont)
        .onValueChanged(of: image) { _ in
            animate = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                animate = false
            }
        }
    }
}
