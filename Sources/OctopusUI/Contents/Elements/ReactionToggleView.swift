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
    let reactionTapped: (ReactionKind?) -> Void

    @State private var showReactionPicker = false
    @State private var screenWidth: CGFloat = .zero

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
                reaction: userReaction?.kind)
            .accessibilityElement(children: .ignore)
            .accessibilityLabelInBundle(
                "Accessibility.Reaction.Button_reaction:\(reactionAccessibilityValue)"
            )
            .accessibilityValueInBundle(
                userReaction != nil
                    ? "Accessibility.Common.Selected"
                    : "Accessibility.Common.NotSelected"
            )
            .modify {
                if #available(iOS 17.0, *) {
                    $0.accessibilityAddTraits(.isToggle)
                } else { $0 }
            }
            .padding(.vertical, 10)
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
        .readScreenWidth($screenWidth)
        .displayableOverlay(
            isPresented: $showReactionPicker,
            horizontalPadding: 12,
            verticalPadding: 12
        ) {
            PopoverReactionsBar(
                reactions: ReactionKind.knownValues,
                screenWidth: screenWidth,
                reactionTapped: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showReactionPicker = false
                    }
                    reactionTapped($0)
                })
        }
    }

    private var reactionAccessibilityValue: String {
        (userReaction?.kind ?? ReactionKind.heart)
            .accessibilityValue(locale: languageManager.overridenLocale)
    }
}

/// `ButtonStyle` that dims the label to 60% opacity while pressed. Exists so the reaction
/// button can show touch-down feedback without resorting to a raw `DragGesture` that would
/// steal the enclosing `ScrollView`'s swipe — `ButtonStyle`'s `isPressed` is what SwiftUI
/// uses internally for exactly this scroll-cooperation.
private struct PressOpacityButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}
