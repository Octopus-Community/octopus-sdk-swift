//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct CreateChildInteractionView: View {
    @Environment(\.octopusTheme) private var theme

    let image: GenImageResource
    let text: LocalizedStringKey

    @State private var animate = false

    private var normalFont: Font { theme.fonts.caption1 }

    init(image: GenImageResource, text: LocalizedStringKey) {
        self.image = image
        self.text = text
    }

    var body: some View {
        HStack(spacing: 4) {
            // make sure the image has the same height as the text. To do that, use a squared font size based
            // transparent image and put our image on overlay of this transparent image
            Image(systemName: "square")
                .font(normalFont)
                .foregroundColor(Color.clear)
                .overlay(
                    Image(res: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .foregroundColor(theme.colors.gray700)
                        .padding(-2) // make it slightly bigger
                        .scaleEffect(animate ? 1.4 : 1.0)
                        .opacity(animate ? 0.9 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.3), value: animate)
                )

            Text(text, bundle: .module)
                .font(normalFont)
                .fontWeight(.medium)
            .foregroundColor(theme.colors.gray700)
        }
        .onValueChanged(of: image) { newValue in
            animate = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                animate = false
            }
        }
    }
}
