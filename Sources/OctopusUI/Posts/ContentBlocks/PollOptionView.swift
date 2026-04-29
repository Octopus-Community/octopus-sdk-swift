//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import OctopusCore

struct PollOptionView: View {
    @Environment(\.octopusTheme) private var theme
    @EnvironmentObject private var translationStore: ContentTranslationPreferenceStore

    enum VoteState: Equatable {
        case waitForUserVote
        case displayResult(percent: Int, isUserChoice: Bool)

        var displayResult: Bool {
            switch self {
            case .waitForUserVote: return false
            case .displayResult: return true
            }
        }

        var isUserChoice: Bool {
            switch self {
            case let .displayResult(_, isUserChoice):
                return isUserChoice
            case .waitForUserVote: return false
            }
        }
    }

    let pollOption: DisplayablePoll.Option
    let optionIdx: Int
    let totalOptionCount: Int
    let state: VoteState
    let parentId: String

    @State private var width: CGFloat = 0

    var body: some View {
        HStack {
            HStack(spacing: 0) {
                Text(pollOption.text.getText(translated: translationStore.displayTranslation(for: parentId)))
                    .font(theme.fonts.body2)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .foregroundColor(state.displayResult ? theme.colors.gray900 : theme.colors.primary)
                    .padding(.leading, 12)
                    .padding(.trailing, 8)
                    .padding(.vertical, 12)
                Spacer()
                if case let .displayResult(_, isUserChoice) = state, isUserChoice {
                    Image(uiImage: theme.assets.icons.content.poll.selectedOption)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(theme.colors.primaryHighContrast)
                }
                Spacer().frame(width: 4) // 4 + 8 = 12
            }
            .fixedSize(horizontal: false, vertical: true)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .modify {
                        if case let .displayResult(percent, _) = state {
                            $0.fill(theme.colors.gray200)
                                .overlay(
                                    Rectangle()
                                        .fill(theme.colors.gray300)
                                        .modify {
                                            if #available(iOS 16.0, *) {
                                                $0.relativeProposed(width: Double(percent) / 100.0)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            } else {
                                                $0.frame(width: width * Double(percent) / 100.0,
                                                         alignment: .leading)
                                            }
                                        },
                                    alignment: .leading
                                )
                        } else {
                            $0.stroke(theme.colors.primary, lineWidth: 1)
                        }
                    }
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .modify {
                if #available(iOS 16.0, *) {
                    $0
                } else {
                    // only needed for pre-iOS 16 where `relativeProposed` is not available
                    $0.readWidth($width)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityHintInBundle("Accessibility.Poll.IdxOption_index:\(optionIdx + 1)_count:\(totalOptionCount)")
            .accessibilityLabelCompat(pollOption.text.getText(translated: translationStore.displayTranslation(for: parentId)))
            .modify {
                if state.displayResult {
                    $0.accessibilityValueInBundle(
                        state.isUserChoice ? "Accessibility.Common.Selected" : "Accessibility.Common.NotSelected"
                    )
                } else { $0 }
            }
            if case let .displayResult(percent, _) = state {
                ZStack {
                    Text(verbatim: "100%") // biggest possible string
                        .foregroundColor(Color.clear)
                        .accessibilityHidden(true)

                    Text(verbatim: "\(percent)%")
                        .foregroundColor(theme.colors.gray900)
                }
                .font(theme.fonts.body2)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview("Not voted") {
    PollOptionView(
        pollOption: DisplayablePoll.Option(
            id: "1",
            text: TranslatableText(originalText: "Option 1", originalLanguage: nil)),
        optionIdx: 0, totalOptionCount: 2,
        state: .waitForUserVote,
        parentId: "p1")
    .padding()
    .mockEnvironmentForPreviews()
}

#Preview("Voted (42% selected)") {
    PollOptionView(
        pollOption: DisplayablePoll.Option(
            id: "1",
            text: TranslatableText(originalText: "Option 1", originalLanguage: nil)),
        optionIdx: 0, totalOptionCount: 2,
        state: .displayResult(percent: 42, isUserChoice: true),
        parentId: "p1")
    .padding()
    .mockEnvironmentForPreviews()
}
