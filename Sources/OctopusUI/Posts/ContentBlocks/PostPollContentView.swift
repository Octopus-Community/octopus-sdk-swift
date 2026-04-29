//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import SwiftUI
import Combine
import OctopusCore

struct PostPollContentView: View {
    @Environment(\.octopusTheme) private var theme

    let postId: String
    let poll: DisplayablePoll
    /// The live measures publisher; caller must provide it.
    let liveMeasuresPublisher: AnyPublisher<LiveMeasures, Never>
    /// Immediate initial snapshot so the first render isn't empty (the publisher is a `CurrentValueSubject` upstream).
    let initialLiveMeasures: LiveMeasures
    let vote: (String) -> Bool

    @State private var liveMeasures: LiveMeasures
    @State private var simulateVote: String?

    init(postId: String,
         poll: DisplayablePoll,
         liveMeasuresPublisher: AnyPublisher<LiveMeasures, Never>,
         initialLiveMeasures: LiveMeasures,
         vote: @escaping (String) -> Bool) {
        self.postId = postId
        self.poll = poll
        self.liveMeasuresPublisher = liveMeasuresPublisher
        self.initialLiveMeasures = initialLiveMeasures
        self.vote = vote
        self._liveMeasures = State(initialValue: initialLiveMeasures)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(poll.options.indices, id: \.self) { pollOptionIdx in
                let pollOption = poll.options[pollOptionIdx]
                Group {
                    let optionState = state(for: pollOption.id)
                    if simulateVote != nil || optionState.displayResult {
                        PollOptionView(
                            pollOption: pollOption,
                            optionIdx: pollOptionIdx,
                            totalOptionCount: poll.options.count,
                            state: optionState,
                            parentId: postId)
                        .animation(.easeInOut, value: optionState)
                    } else {
                        Button(action: {
                            simulateVote = pollOption.id
                            let hasVoted = vote(pollOption.id)
                            if !hasVoted {
                                simulateVote = nil
                            }
                            HapticFeedback.play()
                        }) {
                            PollOptionView(
                                pollOption: pollOption,
                                optionIdx: pollOptionIdx,
                                totalOptionCount: poll.options.count,
                                state: optionState,
                                parentId: postId)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Text(subPollLocalizedKey, bundle: .module)
                .font(theme.fonts.caption2)
                .fontWeight(.medium)
                .foregroundColor(theme.colors.gray700)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, theme.sizes.horizontalPadding)
        .padding(.top, 4)
        .onValueChanged(of: liveMeasures.userInteractions.hasVoted) {
            guard $0 else { return }
            // put back simulateVoting as soon as the user has voted
            simulateVote = nil
        }
        .onReceive(liveMeasuresPublisher) { newLiveMeasures in
            liveMeasures = newLiveMeasures
        }
        // Post detail screen passes an `Empty` publisher and relies on `initialLiveMeasures`
        // changing when the underlying post updates. Mirror the `ResponseActionBarView` /
        // `PostView` pattern so poll state stays live in detail context too.
        .onValueChanged(of: initialLiveMeasures) { liveMeasures = $0 }
    }

    private func state(for optionId: String) -> PollOptionView.VoteState {
        if liveMeasures.userInteractions.hasVoted {
            return .displayResult(
                percent: liveMeasures.aggregatedInfo.pollResult?.percentageResultsByOption[optionId] ?? 0,
                isUserChoice: optionId == liveMeasures.userInteractions.pollVoteId)
        } else if let simulateVote {
            return .displayResult(percent: 0, isUserChoice: optionId == simulateVote)
        } else {
            return .waitForUserVote
        }
    }

    var subPollLocalizedKey: LocalizedStringKey {
        if liveMeasures.userInteractions.hasVoted {
            if let totalVoteCount = liveMeasures.aggregatedInfo.pollResult?.totalVoteCount, totalVoteCount > 1 {
                return "Poll.Results.VoteCount.Plural_total:\(String.formattedCount(totalVoteCount))"
            } else {
                return "Poll.Results.VoteCount.One_total:\("1")" // if hasVoted, the total vote count is > 0
            }
        } else if let totalVoteCount = liveMeasures.aggregatedInfo.pollResult?.totalVoteCount, totalVoteCount >= 5 {
            return "Poll.Results.Hidden.VoteCount_total:\(String.formattedCount(totalVoteCount))"
        } else {
            return "Poll.Results.Hidden.SomeVotes"
        }
    }
}

#Preview("Not voted") {
    PostPollContentView(
        postId: "p1",
        poll: DisplayablePoll(options: [
            .init(id: "1", text: TranslatableText(originalText: "Option 1", originalLanguage: nil)),
            .init(id: "2", text: TranslatableText(originalText: "Option 2", originalLanguage: nil)),
        ]),
        liveMeasuresPublisher: Empty<LiveMeasures, Never>().eraseToAnyPublisher(),
        initialLiveMeasures: LiveMeasures(
            aggregatedInfo: .init(reactions: [], childCount: 0, viewCount: 0, pollResult: nil),
            userInteractions: .empty),
        vote: { _ in false })
    .mockEnvironmentForPreviews()
}
