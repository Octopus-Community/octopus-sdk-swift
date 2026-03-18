//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct PoweredByOctopusView: View {
    @Environment(\.octopusTheme) private var theme
    @EnvironmentObject private var displayConfigManager: DisplayConfigManager

    @State private var textHeight: CGFloat = 0
    @State private var isShowingPopover = false

    var body: some View {
        if case .hidden = displayConfigManager.poweredByConfig {
            EmptyView()
        } else {
            Button(action: { isShowingPopover = true }) {
                switch displayConfigManager.poweredByConfig {
                case .normal:
                    HStack(alignment: .center, spacing: 0) {
                        Text("Common.PoweredBy", bundle: .module)
                            .font(theme.fonts.caption1)
                            .fontWeight(.medium)
                            .readHeight($textHeight)

                        Image(res: .poweredByOctopus)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            // *1.4 because the image is bigger than its text (due to the word Community around)
                            .frame(height: textHeight * 1.4)
                    }
                    .foregroundColor(theme.colors.gray500)
                    .padding(.top, 21)
                case let .custom(urls):
                    AsyncCachedDynamicImage(
                        urls: urls,
                        cache: .interface) { cachedImage in
                            Image(uiImage: cachedImage.fullSizeImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 24)
                        }
                        .padding(.top, 21)
                case .hidden: EmptyView()
                }
            }
            .buttonStyle(.plain)
            .modify {
                if #available(iOS 16.4, *), !UIAccessibility.isVoiceOverRunning {
                    $0.popover(isPresented: $isShowingPopover, arrowEdge: .bottom) {
                        Text(verbatim: "www.octopuscommunity.com")
                            .font(theme.fonts.caption1)
                            .foregroundColor(theme.colors.gray900)
                            .padding(.horizontal)
                            .presentationCompactAdaptation((.popover))
                    }
                } else {
                    $0.disabled(true)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabelInBundle("Accessibility.Common.PoweredBy")
        }
    }
}

#Preview {
    PoweredByOctopusView()
}
