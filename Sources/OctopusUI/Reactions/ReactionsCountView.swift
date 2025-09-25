//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

@available(iOS 16.0, *)
struct ReactionsCountSheetScreen: View {
    let reactions: [ReactionCount]
    @State private var detentHeight: CGFloat = 50

    var body: some View {
        ReactionsCountView(reactions: reactions)
            .readHeight($detentHeight)
            .presentationDetents([.height(detentHeight)])
            .presentationDragIndicator(.visible)
            .modify {
                if #available(iOS 16.4, *) {
                    $0.presentationContentInteraction(.scrolls)
                } else {
                    $0
                }
            }
    }
}

@available(iOS 16.0, *)
struct ReactionsCountView: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.presentationMode) private var presentationMode

    let reactions: [ReactionCount]

    var body: some View {
        FreeGridLayout(alignment: .leading) {
            ForEach(reactions.filter { $0.count > 0 }, id: \.self) { reaction in
                HStack(spacing: 0) {
                    Text(reaction.reaction.unicode)
                    Text(String.formattedCount(reaction.count))
                }
                .font(theme.fonts.caption1.weight(.medium))
                .foregroundColor(theme.colors.gray700)
                .padding(.horizontal, 12)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 35)
        .padding(.bottom, 20)
    }
}
