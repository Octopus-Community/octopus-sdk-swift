//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

struct ReactionsSummary: View {
    @Environment(\.octopusTheme) private var theme
    
    enum CountPlacement {
        case leading
        case trailing
    }

    let reactions: [ReactionCount]
    let countPlacement: CountPlacement
    var maxReactionsKind: Int = 3

    @State private var displayReactionsCount = false

    var body: some View {
        if reactionsCount > 0 {
            Button(action: { displayReactionsCount = true }) {
                HStack(spacing: 2) {
                    if countPlacement == .leading {
                        countView
                            .frame(minWidth: 10) // fix a weird bug in the CommentDetailView where the layout is broken
                    }
                    HStack(spacing: -5) {
                        ForEach(reactionsToDisplay, id: \.self) { reactionKind in
                            Text(reactionKind.unicode)
                                .font(.system(size: 12))
                                .shadow(color: Color(UIColor.systemBackground), radius: 0, x: -1, y: 0)
                        }
                    }
                    if countPlacement == .trailing {
                        countView
                            .frame(minWidth: 10) // fix a weird bug in the CommentDetailView where the layout is broken
                    }
                }
            }
            .sheet(isPresented: $displayReactionsCount) {
                if #available(iOS 16.0, *) {
                    ReactionsCountSheetScreen(reactions: reactions)
                } else {
                    EmptyView()
                }
            }
        } else {
            EmptyView()
        }
    }

    var reactionsCount: Int {
        reactions.reduce(0, { $0 + $1.count })
    }

    var reactionsToDisplay: [ReactionKind] {
        reactions.filter { $0.count > 0 }.prefix(3).map(\.reaction)
    }

    var countView: some View {
        Text(String.formattedCount(reactionsCount))
            .font(theme.fonts.caption1)
            .foregroundColor(theme.colors.gray700)
            .modify {
                if #available(iOS 16.0, *) {
                    $0.contentTransition(.numericText())
                } else {
                    $0
                }
            }
            .animation(.default, value: reactionsCount)
    }
}
