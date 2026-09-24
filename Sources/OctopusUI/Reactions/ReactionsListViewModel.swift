//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import OctopusCore

@MainActor
class ReactionsListViewModel: ObservableObject {
    /// One tab of the sheet: every reaction, or a single kind.
    enum Tab: Hashable {
        case all
        case kind(ReactionKind)

        /// What the backend expects as a filter: `nil` for the All tab.
        var reactionKind: ReactionKind? {
            switch self {
            case .all: nil
            case let .kind(kind): kind
            }
        }
    }

    /// Paging state of a single tab. Each tab pages independently, so switching back and forth does not
    /// restart a list the member already scrolled.
    struct TabContent {
        var reactions: [ProfileReaction] = []
        /// Cursor of the *next* page. `nil` means either "not loaded yet" or "list exhausted" —
        /// `hasLoadedOnce` tells the two apart.
        var nextCursor: String?
        var hasLoadedOnce = false
        var isLoadingFirstPage = false
        var isLoadingMore = false
        var error: DisplayableString?

        var canLoadMore: Bool { hasLoadedOnce && nextCursor != nil && error == nil }
        var isEmpty: Bool { hasLoadedOnce && reactions.isEmpty }
    }

    let tabs: [Tab]
    @Published var selectedTabIndex = 0
    @Published private(set) var contents = [Tab: TabContent]()

    /// Count per reaction kind, from the counters the content already carries, so the tab bar shows its
    /// numbers before any page is fetched. The All tab has no entry: the design shows it without a count.
    let counts: [Tab: Int]

    private let manager: ReactionsListManager
    private let contentId: String
    private let pageSize = 20

    init(manager: ReactionsListManager, contentId: String, reactions: [ReactionCount]) {
        self.manager = manager
        self.contentId = contentId
        let nonEmpty = reactions.filter { !$0.isEmpty }
        // Ordered by volume, most reacted first. Ties keep the backend's own order: the spec breaks them
        // by most recent reaction, and `ReactionCount` carries no date to sort on — only the backend can
        // express that, through the order it sends the counters in. Sorting on (count, original index)
        // rather than `sorted(by:)` alone because Swift's sort is not guaranteed stable, which would
        // scramble exactly that tie-break.
        let ordered = nonEmpty.enumerated()
            .sorted {
                $0.element.count == $1.element.count
                    ? $0.offset < $1.offset
                    : $0.element.count > $1.element.count
            }
            .map { $0.element }
        let kindTabs: [Tab] = ordered.map { .kind($0.reactionKind) }
        switch kindTabs.count {
        case 0:
            // Unreachable from the UI — the summary only opens the sheet when something was reacted —
            // but `selectedTab` indexes into this, so it must never be empty.
            tabs = [.all]
        case 1:
            // A single kind needs no All tab: it would list exactly the same people.
            tabs = kindTabs
        default:
            tabs = [.all] + kindTabs
        }
        var counts = [Tab: Int]()
        for reaction in nonEmpty {
            counts[.kind(reaction.reactionKind)] = reaction.count
        }
        self.counts = counts
    }

    var selectedTab: Tab {
        tabs[max(0, min(selectedTabIndex, tabs.count - 1))]
    }

    func content(for tab: Tab) -> TabContent {
        contents[tab] ?? TabContent()
    }

    /// Loads the first page of a tab, once.
    func loadFirstPageIfNeeded(tab: Tab) async {
        var content = self.content(for: tab)
        guard !content.hasLoadedOnce, !content.isLoadingFirstPage else { return }
        content.isLoadingFirstPage = true
        content.error = nil
        contents[tab] = content
        await load(tab: tab, cursor: nil)
    }

    func loadMore(tab: Tab) async {
        var content = self.content(for: tab)
        guard let cursor = content.nextCursor, content.hasLoadedOnce,
              !content.isLoadingMore, !content.isLoadingFirstPage else { return }
        content.isLoadingMore = true
        content.error = nil
        contents[tab] = content
        await load(tab: tab, cursor: cursor)
    }

    func retry(tab: Tab) async {
        let content = self.content(for: tab)
        // An error on the first page leaves the tab empty and `hasLoadedOnce` false, so retrying it is
        // the same call as the initial load; an error while paging must resume from the cursor instead.
        if content.reactions.isEmpty {
            var reset = content
            reset.error = nil
            reset.hasLoadedOnce = false
            contents[tab] = reset
            await loadFirstPageIfNeeded(tab: tab)
        } else {
            await loadMore(tab: tab)
        }
    }

    private func load(tab: Tab, cursor: String?) async {
        do {
            let page = try await manager.fetch(
                contentId: contentId, kind: tab.reactionKind, cursor: cursor, pageSize: pageSize)
            var content = self.content(for: tab)
            content.reactions += page.reactions
            content.nextCursor = page.nextCursor
            content.hasLoadedOnce = true
            content.isLoadingFirstPage = false
            content.isLoadingMore = false
            contents[tab] = content
        } catch {
            var content = self.content(for: tab)
            content.isLoadingFirstPage = false
            content.isLoadingMore = false
            content.error = Self.message(for: error)
            contents[tab] = content
        }
    }

    private static func message(for error: ServerCallError) -> DisplayableString {
        switch error {
        case .noNetwork: .localizationKey("Error.NoNetwork")
        default: .localizationKey("Error.Unknown")
        }
    }
}
