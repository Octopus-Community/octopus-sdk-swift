//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct PoweredByOctopusView: View {
    @Environment(\.octopusTheme) private var theme

    @State private var textHeight: CGFloat = 0
    @State private var isShowingPopover = false

    var body: some View {
        Button(action: { isShowingPopover = true }) {
            HStack(alignment: .center, spacing: 0) {
                Text("Common.PoweredBy", bundle: .module)
                    .font(theme.fonts.caption1)
                    .fontWeight(.medium)
                    .readHeight($textHeight)
                
                Image(.poweredByOctopus)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    // *1.4 because the image is bigger than its text (due to the word Community around)
                    .frame(height: textHeight * 1.4)
            }
            .foregroundColor(theme.colors.gray500)
            .padding(.top, 4)
        }
        .buttonStyle(.plain)
        .modify {
            if #available(iOS 16.4, *) {
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
    }
}

#Preview {
    PoweredByOctopusView()
}
