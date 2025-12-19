//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

struct ReactionInteractionView: View {
    @Environment(\.octopusTheme) private var theme

    enum ImageKind: Equatable {
        case resource(GenImageResource)
        case emoji(ReactionKind)
    }

    let image: ImageKind
    let text: LocalizedStringKey

    @State private var animate = false

    private var normalFont: Font { theme.fonts.caption1 }

    init(image: ImageKind, text: LocalizedStringKey) {
        self.image = image
        self.text = text
    }

    var body: some View {
        HStack(spacing: 5) {
            // make sure the image has the same height as the text. To do that, use a squared font size based
            // transparent image and put our image on overlay of this transparent image
            Image(systemName: "square")
                .font(normalFont)
                .foregroundColor(Color.clear)
                .overlay(
                    Group {
                        switch image {
                        case let .resource(resource):
                            Image(res: resource)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .foregroundColor(theme.colors.gray700)
                                .padding(-2) // make it slightly bigger
                                .scaleEffect(animate ? 1.4 : 1.0)
                                .opacity(animate ? 0.9 : 1.0)
                                .animation(.spring(response: 0.2, dampingFraction: 0.3), value: animate)
                        case let .emoji(kind):
                            Text(kind.unicode)
                                .minimumScaleFactor(0.5)
                                .foregroundColor(theme.colors.gray700)
                                .scaleEffect(animate ? 1.4 : 1.0)
                                .opacity(animate ? 0.9 : 1.0)
                                .animation(.spring(response: 0.2, dampingFraction: 0.3), value: animate)
                        }
                    }
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
        .modify {
            if #available(iOS 17.0, *) {
                $0.sensoryFeedback(trigger: animate) { oldValue, newValue in
                    guard oldValue != newValue, newValue else { return nil }
                    return .impact(flexibility: .soft)
                }
            } else { $0 }
        }
    }
}
