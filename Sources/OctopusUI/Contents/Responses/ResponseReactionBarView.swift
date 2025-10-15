//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

struct ResponseReactionBarView: View {
    let userReaction: UserReaction?
    let canReply: Bool
    let reactions: [ReactionCount]
    let reactionTapped: (ReactionKind?) -> Void
    let openCreateReply: () -> Void

    @State private var reactionInteractionViewOpacity: CGFloat = 1
    @State private var showReactionPicker = false

    var body: some View {
        HStack(spacing: 24) {
            ReactionInteractionView(
                image: userReaction != nil ? .emoji(userReaction!.kind) : .resource(.AggregatedInfo.like),
                text: "Content.AggregatedInfo.Like")
            .opacity(reactionInteractionViewOpacity)
            .modify {
                if #available(iOS 18.0, *) {
                    $0.gesture(
                        LongPressGesture()
                            .exclusively(before: TapGesture())
                            .onEnded { value in
                                reactionInteractionViewOpacity = 1.0
                                switch value {
                                case .first: // long press
                                    showReactionPicker.toggle()
                                case .second: // tap
                                    guard !showReactionPicker else {
                                        showReactionPicker = false
                                        return
                                    }
                                    reactionTapped(userReaction == nil ? ReactionKind.heart : nil)
                                }
                            }
                    )
                } else {
                    $0.simultaneousGesture(
                        LongPressGesture()
                            .onChanged { _ in
                                reactionInteractionViewOpacity = 0.6
                            }
                            .onEnded { _ in
                                showReactionPicker.toggle()
                                reactionInteractionViewOpacity = 1.0
                            }
                    )
                    .highPriorityGesture(
                        TapGesture()
                            .onEnded { _ in
                                reactionInteractionViewOpacity = 1.0
                                guard !showReactionPicker else {
                                    showReactionPicker = false
                                    return
                                }
                                reactionTapped(userReaction == nil ? ReactionKind.heart : nil)
                            }
                    )
                }
            }
            .simultaneousGesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    // simulate button opacity change when the view is pressed
                    reactionInteractionViewOpacity = 0.6
                }
                .onEnded { _ in
                    reactionInteractionViewOpacity = 1.0
                }
            )
            .displayableOverlay(isPresented: $showReactionPicker,
                                horizontalPadding: 12,
                                verticalPadding: 24) {
                PopoverReactionsBar(reactions: ReactionKind.knownValues,
                                    reactionTapped: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showReactionPicker = false
                    }
                    reactionTapped($0)
                })
            }

            if canReply {
                Button(action: openCreateReply) {
                    CreateChildInteractionView(image: .AggregatedInfo.comment,
                                           text: "Content.AggregatedInfo.Answer")
                }
                .buttonStyle(.plain)
            }

            Spacer()

            ReactionsSummary(reactions: reactions, countPlacement: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }
}
