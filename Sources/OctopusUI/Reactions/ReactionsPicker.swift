//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

struct ReactionsPickerView: View {
    @Environment(\.octopusTheme) private var theme

    let contentId: String
    let userReaction: UserReaction?
    let reactionTapped: (ReactionKind?) -> Void

    @State private var showReactionPicker = false

    private var quickReactions: [ReactionKind] {
        if let userReaction {
            return [userReaction.kind]
        } else {
            let randomReactions = [
                ReactionKind.joy,
                ReactionKind.mouthOpen,
                ReactionKind.clap,
            ]
                .shuffled(seed: UInt64(bitPattern: Int64(contentId.hash)))
                .prefix(upTo: 1)
            return [ReactionKind.heart] + randomReactions
        }
    }

    private var remainingReactions: [ReactionKind] {
        return ReactionKind.knownValues
            .filter { reaction in
                !quickReactions.contains { $0 == reaction }
            }
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(quickReactions, id: \.self) { reaction in
                ReactionButton(reaction: reaction,
                               isSelected: userReaction?.kind == reaction,
                               reactionTapped: reactionTapped)
            }
            if userReaction == nil {
                // Invisible button, with a visible overlay, just to give the correct size to the overlay
                Button(action: { }) {
                    Text(ReactionKind.clap.unicode)
                        .font(theme.fonts.body2)
                        .fixedSize()
                }
                .buttonStyle(OctopusButtonStyle(.small, style: .outline, hasLeadingIcon: true,
                                                hasTrailingIcon: true))
                .opacity(0)
                .overlay(
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showReactionPicker.toggle()
                        }
                    }) {
                        Image(systemName: "plus")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .font(theme.fonts.body1.weight(.thin))
                    }.buttonStyle(OctopusButtonStyle(.small, style: .outline,
                                                     hasLeadingIcon: true,
                                                     hasTrailingIcon: true))
                )
                .displayableOverlay(isPresented: $showReactionPicker,
                                    horizontalPadding: 12,
                                    verticalPadding: 8) {
                    PopoverReactionsBar(reactions: remainingReactions,
                                        reactionTapped: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showReactionPicker = false
                        }
                        reactionTapped($0)
                    })
                }
            }
        }
        .animation(.default, value: userReaction)
        .onValueChanged(of: showReactionPicker) { _ in
            // weirdly needed in order to display the reaction picker on iOS 26
        }
        .onDisappear {
            showReactionPicker = false
        }
    }
}

private struct ReactionButton: View {
    @Environment(\.octopusTheme) private var theme

    let reaction: ReactionKind
    let isSelected: Bool
    let reactionTapped: (ReactionKind?) -> Void

    @State private var animate = false

    var body: some View {
        Button(action: {
            animate = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                animate = false
            }
            reactionTapped(!isSelected ? reaction : nil)
        }) {
            Text(reaction.unicode)
                .font(theme.fonts.body2)
                .fixedSize()
                .scaleEffect(animate ? 1.4 : 1.0)
                .opacity(animate ? 0.9 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.3), value: animate)
        }
        .buttonStyle(
            OctopusButtonStyle(.small, style: .outline,
                               backgroundColor: isSelected ? theme.colors.primaryLowContrast : nil))
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

struct PopoverReactionsBar: View {
    @Environment(\.octopusTheme) private var theme
    
    let reactions: [ReactionKind]
    let reactionTapped: (ReactionKind?) -> Void

    @State private var animate = false

    var body: some View {
        HStack {
            ForEach(reactions, id: \.self) { reaction in
                Button(action: {
                    animate = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        animate = false
                    }
                    reactionTapped(reaction)
                }) {
                    Text(reaction.unicode)
                        .font(theme.fonts.title2)
                        .fixedSize()
                        .scaleEffect(animate ? 1.4 : 1.0)
                        .opacity(animate ? 0.9 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.3), value: animate)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color(.systemBackground))
                .overlay(Capsule().stroke(theme.colors.gray300, lineWidth: 1))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
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
