//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

struct PollView: View {
    @Environment(\.octopusTheme) private var theme
    let poll: DisplayablePoll

    let aggregatedInfo: AggregatedInfo
    let userInteractions: UserInteractions
    let parentId: String
    let vote: (String) -> Bool

    @State private var simulateVote: String?

    var body: some View {
        VStack(spacing: 8) {
            ForEach(poll.options, id: \.id) { pollOption in
                Group {
                    let state = state(for: pollOption.id)
                    if simulateVote != nil || state.displayResult {
                        PollOptionView(pollOption: pollOption, state: state, parentId: parentId)
                            .animation(.easeInOut, value: state) // Animates changes
                    } else {
                        Button(action: {
                            simulateVote = pollOption.id
                            let hasVoted = vote(pollOption.id)
                            if !hasVoted {
                                simulateVote = nil
                            }
                        }) {
                            PollOptionView(pollOption: pollOption, state: state, parentId: parentId)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if let totalVoteCount = aggregatedInfo.pollResult?.totalVoteCount,
               userInteractions.hasVoted || totalVoteCount >= 4 {
                Text("Poll.Results.VoteCount_total:\(totalVoteCount)", bundle: .module)
                    .font(theme.fonts.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(theme.colors.gray700)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
        }
        .onValueChanged(of: userInteractions.hasVoted) {
            guard $0 else { return }
            // put back simulateVoting as soon as the user has voted
            simulateVote = nil
        }
    }

    private func state(for optionId: String) -> PollOptionView.VoteState {
        if userInteractions.hasVoted {
            return .displayResult(percent: aggregatedInfo.pollResult?.percentageResultsByOption[optionId] ?? 0,
                                  isUserChoice: optionId == userInteractions.pollVoteId)
        } else if let simulateVote {
            return .displayResult(percent: 0, isUserChoice: optionId == simulateVote)
        } else {
            return .waitForUserVote
        }
    }

    
}

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
    }

    let pollOption: DisplayablePoll.Option
    let state: VoteState
    let parentId: String

    @State private var width: CGFloat = 0

    var body: some View {
        HStack {
            HStack {
                Text(pollOption.text.getText(translated: translationStore.displayTranslation(for: parentId)))
                    .font(theme.fonts.body2)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .foregroundColor(state.displayResult ? theme.colors.gray900 : theme.colors.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 11)
                Spacer()
                if case let .displayResult(_, isUserChoice) = state, isUserChoice {
                    Image(systemName: "checkmark.circle")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(theme.colors.primaryHighContrast)
                }
            }
            .padding(.horizontal, 4)
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
            if case let .displayResult(percent, _) = state {
                ZStack {
                    Text(verbatim: "100%") // biggest possible string
                        .foregroundColor(Color.clear)

                    Text(verbatim: "\(percent)%")
                        .foregroundColor(theme.colors.gray900)
                }
                .font(theme.fonts.body2)
            }
        }
    }
}



extension View {
    /// Proposes a percentage of its received proposed size to `self`.
    ///
    /// This modifier multiplies the proposed size it receives from its parent
    /// with the given factors for width and height.
    ///
    /// If the parent proposes `nil` or `.infinity` to us in any dimension,
    /// we’ll forward these values to our child view unchanged.
    ///
    /// - Note: The size we propose to `self` will not necessarily be a percentage
    ///   of the parent view’s actual size or of the available space as not all
    ///   views propose the full available space to their children. For example,
    ///   VStack and HStack divide the available space among their subviews and
    ///   only propose a fraction to each subview.
    @available(iOS 16.0, *)
    public func relativeProposed(width: Double = 1, height: Double = 1) -> some View {
        RelativeSizeLayout(relativeWidth: width, relativeHeight: height) {
            // Wrap content view in a container to make sure the layout only
            // receives a single subview.
            // See Chris Eidhof, SwiftUI Views are Lists (2023-01-25)
            // <https://chris.eidhof.nl/post/swiftui-views-are-lists/>
            VStack { // alternatively: `_UnaryViewAdaptor(self)`
                self
            }
        }
    }
}

/// A custom layout that proposes a percentage of its
/// received proposed size to its subview.
///
/// - Precondition: must contain exactly one subview.
@available(iOS 16.0, *)
fileprivate struct RelativeSizeLayout: Layout {
    var relativeWidth: Double
    var relativeHeight: Double

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        assert(subviews.count == 1, "RelativeSizeLayout expects a single subview")
        let resizedProposal = ProposedViewSize(
            width: proposal.width.map { $0 * relativeWidth },
            height: proposal.height.map { $0 * relativeHeight }
        )
        return subviews[0].sizeThatFits(resizedProposal)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        assert(subviews.count == 1, "RelativeSizeLayout expects a single subview")
        let resizedProposal = ProposedViewSize(
            width: proposal.width.map { $0 * relativeWidth },
            height: proposal.height.map { $0 * relativeHeight }
        )
        subviews[0].place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center, proposal: resizedProposal)
    }
}
