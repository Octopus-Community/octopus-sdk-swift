//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

/// A reaction button that toggles heart on tap and opens the full picker on long-press.
/// Used by both post footers and comment/reply reaction bars.
struct ReactionToggleView: View {
    @EnvironmentObject private var languageManager: LanguageManager

    let likeNotSelectedImage: UIImage
    let userReaction: UserReaction?
    /// The name of the reaction on comments and replies, the total of reactions on posts.
    var caption: ReactionInteractionView.Caption = .reactionLabel
    /// Inside the tap area, so that a bar can keep its icons on the screen's gutter while the button reaches past it.
    var horizontalPadding: CGFloat = 0
    let reactionTapped: (ReactionKind?) -> Void

    @State private var showReactionPicker = false

    var body: some View {
        // `Button` + a custom `ButtonStyle` that reads `configuration.isPressed` is Apple's
        // sanctioned way to get touch-down press feedback without stealing swipes from an
        // enclosing `ScrollView`. The framework knows how to hand the touch back to the
        // scroll view when it detects a drag. Raw gestures (`DragGesture`, `LongPressGesture`
        // with `.updating`) fire on touch-down and end up capturing the touch before the
        // scroll view has a chance to claim it — do not add an opacity-tracking gesture
        // here or scrolling breaks.
        Button(action: {
            guard !showReactionPicker else {
                showReactionPicker = false
                return
            }
            reactionTapped(userReaction == nil ? ReactionKind.heart : nil)
        }) {
            ReactionInteractionView(
                defaultImage: likeNotSelectedImage,
                reaction: userReaction?.kind,
                caption: caption)
            .accessibilityElement(children: .ignore)
            .modify {
                if #available(iOS 14.0, *) {
                    $0.accessibilityLabel(accessibilityLabel)
                        .accessibilityValue(accessibilityValue)
                } else { $0 }
            }
            .modify {
                if #available(iOS 17.0, *) {
                    $0.accessibilityAddTraits(.isToggle)
                } else { $0 }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, horizontalPadding)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressOpacityButtonStyle())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.3)
                .onEnded { _ in
                    HapticFeedback.play()
                    showReactionPicker.toggle()
                }
        )
        .displayableOverlay(
            isPresented: $showReactionPicker,
            horizontalPadding: 12,
            verticalPadding: 12
        ) { windowSafeArea in
            PopoverReactionsBar(
                reactions: ReactionKind.knownValues,
                availableWidth: windowSafeArea.width,
                reactionTapped: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showReactionPicker = false
                    }
                    reactionTapped($0)
                })
        }
    }

    /// "Like reaction" under a comment, where the name is on screen. Under a post only the count is: VoiceOver reads
    /// "Like, 192 reactions", the name of the reaction followed by the total.
    private var accessibilityLabel: Text {
        switch caption {
        case .reactionLabel:
            Text("Accessibility.Reaction.Button_reaction:\(reactionAccessibilityValue)", bundle: .module)
        case .count:
            Text(verbatim: reactionAccessibilityValue)
        }
    }

    private var accessibilityValue: Text {
        let selection = Text(
            userReaction != nil ? "Accessibility.Common.Selected" : "Accessibility.Common.NotSelected",
            bundle: .module)
        guard case let .count(count) = caption, count > 0 else { return selection }
        return Text("Accessibility.Reaction.Count_count:\(count)", bundle: .module) + Text(verbatim: ", ") + selection
    }

    private var reactionAccessibilityValue: String {
        (userReaction?.kind ?? ReactionKind.heart)
            .accessibilityValue(locale: languageManager.overridenLocale)
    }
}
