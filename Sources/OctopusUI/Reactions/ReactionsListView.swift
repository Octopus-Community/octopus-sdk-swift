//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

/// The "who reacted" bottom sheet: one tab per reaction kind present on the content, plus an All tab,
/// each listing the members who reacted, most recent first.
@available(iOS 16.0, *)
struct ReactionsListSheetScreen: View {
    @EnvironmentObject private var reactionsListManager: ReactionsListManager

    let contentId: String
    let reactions: [ReactionCount]
    let displayProfile: (_ profileId: String, _ clientUserId: String?) -> Void

    var body: some View {
        ReactionsListView(
            manager: reactionsListManager,
            contentId: contentId,
            reactions: reactions,
            displayProfile: displayProfile)
    }
}

@available(iOS 16.0, *)
struct ReactionsListView: View {
    @Environment(\.octopusTheme) private var theme
    @Environment(\.presentationMode) private var presentationMode

    @Compat.StateObject private var viewModel: ReactionsListViewModel
    private let displayProfile: (_ profileId: String, _ clientUserId: String?) -> Void

    init(manager: ReactionsListManager, contentId: String, reactions: [ReactionCount],
         displayProfile: @escaping (_ profileId: String, _ clientUserId: String?) -> Void) {
        _viewModel = Compat.StateObject(
            wrappedValue: ReactionsListViewModel(
                manager: manager, contentId: contentId, reactions: reactions))
        self.displayProfile = displayProfile
    }

    var body: some View {
        VStack(spacing: 0) {
            ReactionTabsBar(
                tabs: viewModel.tabs,
                counts: viewModel.counts,
                selectedIndex: $viewModel.selectedTabIndex)
                // Just enough to clear the system drag indicator drawn over the sheet's top edge —
                // the design keeps the tab bar close to it.
                .padding(.top, 16)
            // A page controller, so the lists can be swiped between as well as tapped. Each page keeps
            // its own scroll position and its own pages of results.
            TabView(selection: $viewModel.selectedTabIndex) {
                ForEach(viewModel.tabs.indices, id: \.self) { index in
                    list(for: viewModel.tabs[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(theme.colors.background)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            Task { await viewModel.loadFirstPageIfNeeded(tab: viewModel.selectedTab) }
        }
        .onValueChanged(of: viewModel.selectedTabIndex) { _ in
            // Each tab keeps its own pages, so coming back to one already loaded shows it right away
            // instead of restarting from the top.
            Task { await viewModel.loadFirstPageIfNeeded(tab: viewModel.selectedTab) }
        }
    }

    @ViewBuilder
    private func list(for tab: ReactionsListViewModel.Tab) -> some View {
        let content = viewModel.content(for: tab)
        ScrollView {
            LazyVStack(spacing: 0) {
                // Indexed on purpose: entries have no stable id of their own (a deleted member has no
                // profile at all), and pages are only ever appended.
                ForEach(content.reactions.indices, id: \.self) { index in
                    ReactionProfileCell(
                        reaction: content.reactions[index],
                        displayProfile: { profileId, clientUserId in
                            // The profile is pushed on the navigation stack *under* this sheet: without
                            // closing it first, the push would happen out of sight.
                            presentationMode.wrappedValue.dismiss()
                            displayProfile(profileId, clientUserId)
                        })
                }
                footer(tab: tab, content: content)
            }
        }
    }

    @ViewBuilder
    private func footer(tab: ReactionsListViewModel.Tab,
                        content: ReactionsListViewModel.TabContent) -> some View {
        if content.isLoadingFirstPage || content.isLoadingMore {
            Compat.ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
        } else if let error = content.error {
            VStack(spacing: 8) {
                error.textView
                    .font(theme.fonts.body2)
                    .foregroundColor(theme.colors.gray700)
                    .multilineTextAlignment(.center)
                Button(action: { Task { await viewModel.retry(tab: tab) } }) {
                    Text("Common.Retry", bundle: .module)
                        .font(theme.fonts.body2.weight(.semibold))
                        .foregroundColor(theme.colors.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, theme.sizes.horizontalPadding)
            .padding(.vertical, 20)
        } else if content.canLoadMore {
            // Paging is triggered by reaching the end of the list rather than by a button.
            Color.clear
                .frame(height: 1)
                .onAppear {
                    Task { await viewModel.loadMore(tab: tab) }
                }
        }
    }
}

/// Horizontal tab strip, in the design system's tab style: 44pt tall, 2pt underline on the selected one.
/// Scrolls horizontally because the number of tabs follows the reaction kinds actually used, which can
/// overflow the width.
@available(iOS 16.0, *)
private struct ReactionTabsBar: View {
    @Environment(\.octopusTheme) private var theme
    @EnvironmentObject private var languageManager: LanguageManager

    let tabs: [ReactionsListViewModel.Tab]
    let counts: [ReactionsListViewModel.Tab: Int]
    @Binding var selectedIndex: Int

    @Compat.ScaledMetric(relativeTo: .body) private var reactionImageSize: CGFloat = 20
    /// The design system's tab height.
    @Compat.ScaledMetric(relativeTo: .body) private var tabHeight: CGFloat = 44

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(tabs.indices, id: \.self) { index in
                    tabView(index: index)
                }
            }
            // 8 here + 8 inside each tab gives the first label the theme's 16pt margin, while the tap
            // areas stay adjacent.
            .padding(.horizontal, 8)
        }
        .frame(height: tabHeight)
        // Drawn behind so the selected tab's 2pt underline covers it, as in the design where the two
        // share a baseline. Inset to the content margin rather than running edge to edge.
        .background(alignment: .bottom) {
            theme.colors.gray300
                .frame(height: 1)
                .padding(.horizontal, theme.sizes.horizontalPadding)
        }
    }

    @ViewBuilder
    private func tabView(index: Int) -> some View {
        let tab = tabs[index]
        let isSelected = selectedIndex == index
        HStack(spacing: 4) {
            switch tab {
            case .all:
                // No count here, per the design: the total is implied by the per-kind tabs.
                Text("Reaction.List.Tabs.All", bundle: .module)
            case let .kind(kind):
                Image(uiImage: theme.assets.icons.content.reaction[kind])
                    .resizable()
                    .scaledToFit()
                    .frame(width: reactionImageSize, height: reactionImageSize)
                Text(String.formattedCount(counts[tab] ?? 0))
            }
        }
        .font(theme.fonts.body2.weight(.medium))
        .foregroundColor(isSelected ? theme.colors.primary : theme.colors.gray700)
        .frame(height: tabHeight)
        // On the label's own width, not the tap area's: the design underlines the text, and padding
        // added outside this overlay would widen the bar.
        .overlay(alignment: .bottom) {
            Rectangle()
                .frame(height: 2)
                .foregroundColor(isSelected ? theme.colors.primary : .clear)
        }
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(duration: 0.2)) { selectedIndex = index }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        // Combining the children would announce a bare "54": the reaction is an image with no label.
        .modify {
            switch tab {
            case .all:
                $0.accessibilityLabelInBundle("Reaction.List.Tabs.All")
            case let .kind(kind):
                $0.accessibilityLabelInBundle(
                    // swiftlint:disable:next line_length
                    "Accessibility.Reaction.Count_reaction:\(kind.accessibilityValue(locale: languageManager.overridenLocale))_count:\(counts[tab] ?? 0)")
            }
        }
        .accessibilityValueInBundle(
            isSelected ? "Accessibility.Common.Selected" : "Accessibility.Common.NotSelected")
    }
}

/// One row of the list: the member who reacted, with their reaction badged on their avatar.
@available(iOS 16.0, *)
private struct ReactionProfileCell: View {
    @Environment(\.octopusTheme) private var theme
    @EnvironmentObject private var languageManager: LanguageManager

    let reaction: ProfileReaction
    let displayProfile: (_ profileId: String, _ clientUserId: String?) -> Void

    @Compat.ScaledMetric(relativeTo: .largeTitle) private var avatarSize: CGFloat = 40
    @Compat.ScaledMetric(relativeTo: .body) private var reactionImageSize: CGFloat = 16

    var body: some View {
        // `Author` already renders a missing profile as the deleted-user placeholder, and
        // `OpenProfileButton` does nothing when there is no profile id to open.
        let author = Author(profile: reaction.profile, gamificationLevel: nil)
        OpenProfileButton(author: author, displayProfile: displayProfile, style: .pressOpacity) {
            HStack(spacing: 12) {
                AuthorAvatarView(avatar: author.avatar)
                    .frame(width: avatarSize, height: avatarSize)
                    // Badged on the avatar rather than trailing the row, as the design has it: it reads
                    // as "this member reacted with this" instead of as a separate column.
                    .overlay(alignment: .bottomTrailing) {
                        Image(uiImage: theme.assets.icons.content.reaction[reaction.kind])
                            .resizable()
                            .scaledToFit()
                            .frame(width: reactionImageSize, height: reactionImageSize)
                            // Straddles the avatar's edge, as in the design.
                            .offset(x: 2, y: 2)
                    }
                author.name.textView
                    .font(theme.fonts.body2.weight(.medium))
                    .foregroundColor(theme.colors.gray900)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, theme.sizes.horizontalPadding)
            // 8 + the 40pt avatar gives the design's 56pt row.
            .padding(.vertical, 8)
        }
        // The badge is a bare image: without this, the row would announce the name only and the reaction
        // — the whole point of the list — would be lost.
        .accessibilityValue(Text(reaction.kind.accessibilityValue(locale: languageManager.overridenLocale)))
    }
}
