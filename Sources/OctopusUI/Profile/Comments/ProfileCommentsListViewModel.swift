//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import SwiftUI
import Octopus
import OctopusCore

/// One entry of the profile Comments tab: the parent post (rendered with the feed's
/// `PostSummaryView`) plus the member's comment or reply (rendered with `ResponseFeedItemView`), reusing
/// the feed's display models so the cell matches the feed's look (reactions, counts, media, replies…).
struct DisplayableUserComment: Identifiable, Equatable {
    let id: String
    /// The parent post shown as context.
    let post: DisplayablePost
    /// The member's own comment or reply.
    let response: DisplayableFeedResponse
    /// For a reply: the parent comment it answers (shown above the reply). `nil` for a comment.
    let parentComment: DisplayableFeedResponse?
}

@MainActor
final class ProfileCommentsListViewModel: ObservableObject {
    @Published private(set) var comments: [DisplayableUserComment]?
    @Published private(set) var hasMoreData = true
    /// Set when loading another user's feed is refused server-side — the tab should be hidden.
    @Published private(set) var isForbidden = false
    /// Set when the *first* load failed with nothing to show, so the tab offers a retry instead of an
    /// empty list. Cleared as soon as a load succeeds.
    @Published private(set) var loadFailure: ScreenStateFailure?

    let octopus: OctopusSDK
    /// `true` for the connected user's own profile — errors surface as an empty state rather than hiding.
    let isOwnProfile: Bool
    let feedId: String
    private let dateFormatter: RelativeDateTimeFormatter
    private var nextPageCursor: String?
    private var isLoading = false

    /// One live-measures subject per content id, seeded from the fetched page and kept up to date by an
    /// observation of the content database (below). Reacting writes to that database, so the subject —
    /// and therefore the cell — updates in place, and self-corrects if the server call fails and the
    /// optimistic DB write is reverted.
    private var liveMeasures: [String: CurrentValueSubject<LiveMeasures, Never>] = [:]
    /// Latest Core content per id, refreshed by the observation so a follow-up reaction (e.g. undo)
    /// carries the real reaction id rather than a stale snapshot.
    private var coreContent: [String: CoreContent] = [:]
    private var observations: [String: AnyCancellable] = [:]

    private enum CoreContent {
        case post(Post)
        case comment(Comment)
        case reply(Reply)
    }

    init(octopus: OctopusSDK, feedId: String, isOwnProfile: Bool) {
        self.octopus = octopus
        self.feedId = feedId
        self.isOwnProfile = isOwnProfile
        self.dateFormatter = RelativeDateTimeFormatterProvider(octopus: octopus).formatter
    }

    func refresh() async {
        // `.onAppear`-driven initial load (iOS 13 has no `.task`): only load the first time.
        guard comments == nil else { return }
        guard !feedId.isEmpty else {
            comments = []
            hasMoreData = false
            return
        }
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            var page = try await octopus.core.userCommentsRepository.firstPage(feedId: feedId)
            var mapped = map(page, base: 0)
            // An empty page with a non-nil cursor is NOT the end: heavy server-side ACL filtering (and the
            // local orphan drop in `display`) can empty a page while items remain. Keep paging until we
            // have something to show or the cursor is nil — otherwise the tab is stranded on the empty
            // state with `hasMoreData == true` and nothing ever re-triggers paging (no rows → no
            // `onRowAppear`). Mirrors `Feed.fetchAll(until:)` and the repository contract.
            while mapped.isEmpty, let cursor = page.nextPageCursor {
                page = try await octopus.core.userCommentsRepository.nextPage(pageCursor: cursor)
                mapped += map(page, base: mapped.count)
            }
            comments = mapped
            loadFailure = nil
            nextPageCursor = page.nextPageCursor
            hasMoreData = page.nextPageCursor != nil
        } catch {
            handle(error)
        }
    }

    func loadMoreIfNeeded(currentItem: DisplayableUserComment) async {
        guard hasMoreData, !isLoading, nextPageCursor != nil,
              comments?.suffix(3).contains(currentItem) == true else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            var cursor = nextPageCursor
            var newItems: [DisplayableUserComment] = []
            // Same guard as `refresh`: a run of empty-after-filter pages must not stall pagination, so keep
            // fetching while pages map to nothing but a cursor remains.
            repeat {
                guard let currentCursor = cursor else { break }
                let page = try await octopus.core.userCommentsRepository.nextPage(pageCursor: currentCursor)
                newItems += map(page, base: (comments?.count ?? 0) + newItems.count)
                cursor = page.nextPageCursor
            } while newItems.isEmpty && cursor != nil
            comments = (comments ?? []) + newItems
            nextPageCursor = cursor
            hasMoreData = cursor != nil
        } catch {
            handle(error)
        }
    }

    /// Maps a fetched page onto the display models, dropping items that can't be anchored (see `display`).
    /// `base` is the running index so `DisplayablePost.position` stays continuous across pages.
    private func map(_ page: UserCommentsPage, base: Int) -> [DisplayableUserComment] {
        page.comments.enumerated().compactMap { display($0.element, position: base + $0.offset) }
    }

    /// Reacts to (or un-reacts from) a content shown in the cell. Routes to the matching repository using
    /// the latest observed Core object; the optimistic DB write it performs flows back through the
    /// observation to the live-measures subject, toggling the cell in place.
    func setReaction(_ reaction: ReactionKind?, contentId: String) {
        guard let content = coreContent[contentId] else { return }
        Task {
            do {
                switch content {
                case let .post(post):
                    try await octopus.core.postsRepository.set(reaction: reaction, post: post, parentIsTranslated: false)
                case let .comment(comment):
                    try await octopus.core.commentsRepository.set(
                        reaction: reaction, comment: comment, parentIsTranslated: false)
                case let .reply(reply):
                    try await octopus.core.repliesRepository.set(
                        reaction: reaction, reply: reply, parentIsTranslated: false)
                }
            } catch {
                // The repository reverts its optimistic DB write on failure, so the observation restores
                // the previous state in the cell — nothing else to do here.
            }
        }
    }

    /// Maps a Core `UserComment` onto the feed display models. Returns `nil` when the parent post can't
    /// be resolved (a reply whose grandparent post wasn't shipped) — nothing to anchor the cell on.
    private func display(_ userComment: UserComment, position: Int) -> DisplayableUserComment? {
        guard let corePost = userComment.post else { return nil }
        let thisUserProfileId = octopus.core.profileRepository.profile?.id

        let post = DisplayablePost(
            from: corePost, position: position, isLast: false, gamificationLevels: [],
            liveMeasuresPublisher: makeLiveMeasures(
                corePost, wrap: { .post($0) },
                fetch: { [octopus] in octopus.core.postsRepository.getPost(uuid: $0) }),
            childLiveMeasuresPublisher: nil, thisUserProfileId: thisUserProfileId, topic: nil,
            dateFormatter: dateFormatter, onAppear: {}, onDisappear: {})

        let response: DisplayableFeedResponse
        var parentComment: DisplayableFeedResponse?
        switch userComment.content {
        case let .comment(comment):
            response = DisplayableFeedResponse(
                from: comment, gamificationLevels: [],
                liveMeasurePublisher: makeLiveMeasures(
                    comment, wrap: { .comment($0) },
                    fetch: { [octopus] in octopus.core.commentsRepository.getComment(uuid: $0) }),
                thisUserProfileId: thisUserProfileId, dateFormatter: dateFormatter,
                onAppearAction: {}, onDisappearAction: {})
        case let .reply(reply):
            response = DisplayableFeedResponse(
                from: reply, gamificationLevels: [],
                liveMeasurePublisher: makeLiveMeasures(
                    reply, wrap: { .reply($0) },
                    fetch: { [octopus] in octopus.core.repliesRepository.getReply(uuid: $0) }),
                thisUserProfileId: thisUserProfileId, dateFormatter: dateFormatter,
                onAppearAction: {}, onDisappearAction: {})
            if let parent = userComment.parentComment {
                parentComment = DisplayableFeedResponse(
                    from: parent, gamificationLevels: [],
                    liveMeasurePublisher: makeLiveMeasures(
                        parent, wrap: { .comment($0) },
                        fetch: { [octopus] in octopus.core.commentsRepository.getComment(uuid: $0) }),
                    thisUserProfileId: thisUserProfileId, dateFormatter: dateFormatter,
                    onAppearAction: {}, onDisappearAction: {})
            }
        }

        // The profile feed omits the count-driving comment's `childCount` (the member's own comment for a
        // top-level entry, the parent comment for a reply), so the "See N replies" row would be missing on
        // first load. Fetch that comment: its `childCount` lands in the DB and the observation set up above
        // surfaces it to the row without leaving the screen.
        let countCommentId = userComment.parentComment?.uuid ?? userComment.id
        Task { try? await octopus.core.commentsRepository.fetchComment(uuid: countCommentId) }

        return DisplayableUserComment(
            id: userComment.id, post: post, response: response, parentComment: parentComment)
    }

    // MARK: - Live measures observation

    /// Builds (or reuses) the live-measures subject for a content and wires the DB observation that keeps
    /// it — and the cached `CoreContent` for follow-up reactions — up to date. `Post`/`Comment`/`Reply`
    /// share this via their `OctopusContent` conformance; `wrap` boxes the content into `CoreContent` and
    /// `fetch` is the matching repository getter.
    private func makeLiveMeasures<T: OctopusContent>(
        _ content: T,
        wrap: @escaping (T) -> CoreContent,
        fetch: @escaping (String) -> AnyPublisher<T?, Never>
    ) -> CurrentValueSubject<LiveMeasures, Never> {
        let id = content.uuid
        let subject = subject(for: id,
                              initial: LiveMeasures(aggregatedInfo: content.aggregatedInfo,
                                                    userInteractions: content.userInteractions))
        coreContent[id] = wrap(content)
        observe(id) { [weak self] in
            fetch(id)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] fresh in
                    guard let fresh else { return }
                    self?.coreContent[id] = wrap(fresh)
                    self?.liveMeasures[id]?.send(
                        LiveMeasures(aggregatedInfo: fresh.aggregatedInfo, userInteractions: fresh.userInteractions))
                }
        }
        return subject
    }

    private func subject(for id: String,
                         initial: LiveMeasures) -> CurrentValueSubject<LiveMeasures, Never> {
        if let existing = liveMeasures[id] {
            existing.send(initial)
            return existing
        }
        let subject = CurrentValueSubject<LiveMeasures, Never>(initial)
        liveMeasures[id] = subject
        return subject
    }

    private func observe(_ id: String, _ makeCancellable: () -> AnyCancellable?) {
        guard observations[id] == nil else { return }
        observations[id] = makeCancellable()
    }

    private func handle(_ error: ServerCallError) {
        // A rights refusal keeps the tab's own rule: it is only offered on another member's
        // profile when the community allows it, so being refused there means hiding it rather than
        // showing an error the viewer can do nothing about.
        if !isOwnProfile, isRightsRefusal(error) {
            isForbidden = true
            return
        }
        // Anything else is a load that failed and can be retried — as a screen state when the tab is
        // still empty, as a toast once comments are displayed (Screen states spec).
        if comments?.isEmpty ?? true {
            loadFailure = ScreenStateFailure(error)
            hasMoreData = false
        } else if case .noNetwork = error {
            octopus.core.toastsRepository.display(errorToast: .noNetwork)
        } else {
            octopus.core.toastsRepository.display(errorToast: .unknown)
        }
    }

    private func isRightsRefusal(_ error: ServerCallError) -> Bool {
        guard case let .serverError(serverError) = error else { return false }
        switch serverError {
        case .permissionDenied, .notAuthenticated: return true
        default: return false
        }
    }

    /// Re-runs the first load after a failure.
    func retry() async {
        loadFailure = nil
        hasMoreData = true
        await refresh()
    }
}
