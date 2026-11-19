//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import SwiftUI
import Octopus
import OctopusCore
import UIKit
import os

@MainActor
class PostDetailViewModel: ObservableObject {

    struct Post: Equatable {
        struct BridgeCTA: Equatable {
            let text: TranslatableText
            let clientObjectId: String
        }
        struct CustomAction: Equatable {
            let ctaText: TranslatableText
            let targetUrl: URL
        }
        let uuid: String
        let text: TranslatableText
        let attachments: PostAttachmentsViewData
        let author: Author
        let relativeDate: DisplayableDate
        let topic: String?
        /// Identifier of the post's group (its `parentId`). Backs the "View group" menu entry.
        let groupId: String?
        let aggregatedInfo: AggregatedInfo
        let userInteractions: UserInteractions
        let canBeDeleted: Bool
        let canBeModerated: Bool
        let canBeBlockedByUser: Bool
        let canCreateChildren: Bool
        let catchPhrase: TranslatableText?
        let bridgeCTA: BridgeCTA?
        let customAction: CustomAction?
    }

    enum PostDeletion {
        case inProgress
        case done
    }

    @Published private(set) var post: Post?
    @Published private(set) var error: DisplayableString?

    // Comments
    private var feedStorage = [AnyCancellable]()
    private var feed: Feed<Comment, Never>?

    @Published private(set) var comments: [DisplayableFeedResponse]?
    /// Set when the comments' first load fails with nothing listed yet.
    @Published private(set) var commentsLoadFailure: ScreenStateFailure?
    /// Set when the post itself could not be loaded and none was cached. Without it the screen spins
    /// forever: the comments cannot load either, so nothing reports the failure.
    @Published private(set) var contentLoadFailure: ScreenStateFailure?
    /// Whether the comments' first load has settled. Comments come from the local store first, so an
    /// empty list before that means "still loading".
    @Published private(set) var hasLoadedComments = false
    @Published var scrollToBottom = false
    @Published var scrollToId: String?
    @Published var commentTextFocused = false
    @Published private(set) var hasMoreData = false
    @Published private(set) var hideLoadMoreCommentsLoader = false
    /// Whether the list shows the most recent end of the thread (see ``MostRecentWindow``): set when the screen opens
    /// on its newest comments or once a comment is sent, so a long thread is never loaded whole.
    @Published private(set) var listsMostRecentEnd = false
    /// Whether the list is the window around the comment the screen opened on, newer comments than the ones listed
    /// still to load below them.
    @Published private(set) var hasNewerComments = false
    /// The window of the thread the comments listed come from, `nil` when they are listed oldest first. Set with the
    /// first comments of a window: until then, the ones of the previous list stay.
    @Published private(set) var listedWindowId: String?
    /// Whether the list is hidden while it lands on the most recent end: its first layout is at its top, and showing it
    /// there would draw the oldest comments of the window for a frame before the jump to the newest one. Not when nothing
    /// is stored to land on: the post then shows at once instead of waiting for the server.
    @Published private(set) var hidesListUntilLanded = false
    /// Whether the scrolls that land the list on its most recent end are not animated, until the one landing it on the
    /// server's window ended: animating them would scroll through the window, or from a stale stored window.
    @Published private(set) var landsWithoutAnimation = false
    @Published var scrollRequest: Compat.ScrollRequest?
    @Published private var modelComments: [Comment]?
    private var autoFetchLatestCommentsTask: Task<Void, Swift.Error>?
    private var autoFetchLatestCommentsCancellable: AnyCancellable?

    @Published var postDeletion: PostDeletion?

    @Published var isDeletingComment = false
    @Published var commentDeleted = false

    @Published var postNotAvailable = false
    @Published var postDisappeared = false
    @Published var lockedState: LockedContentState = .unlocked

    var canDisplayClientObject: Bool { octopus.displayClientObjectCallback != nil }

    private var shouldFetchLatestComments = CurrentValueSubject<Bool, Never>(false)
    private var liveMeasures: [String: CurrentValueSubject<LiveMeasures, Never>] = [:]

    var postAuthorName: DisplayableString? {
        if let post {
            return post.author.name
        } else if let internalPost {
            return Author(profile: internalPost.author, gamificationLevel: nil).name
        }
        return nil
    }

    var thisUserProfileId: String? {
        octopus.core.profileRepository.profile?.id
    }

    @Published var authenticationAction: ConnectedActionReplacement?
    var authenticationActionBinding: Binding<ConnectedActionReplacement?> {
        Binding(
            get: { self.authenticationAction },
            set: { self.authenticationAction = $0 }
        )
    }

    let octopus: OctopusSDK
    let postUuid: String
    let connectedActionChecker: ConnectedActionChecker
    private let nicknameChoiceClosedSubject = PassthroughSubject<Void, Never>()
    private let translationStore: ContentTranslationPreferenceStore
    private var newestFirstCommentsFeed: Feed<Comment, Never>?
    /// The comment the screen opened on, until the screen has scrolled to it.
    private var scrollTarget: PendingScrollTarget
    /// Whether the comments are listed from the first one down to the comment the screen opened on, when the thread
    /// could not be opened on it. The list is then built whole: a lazy list has not built a row far below the fold
    /// yet, so a scroll to it would find nothing and be lost. The window around the comment stays lazy instead, its
    /// rows laid out at once (see `MostRecentWindow.laidOutEnd`).
    @Published private(set) var listsDownToTargetComment = false
    private var scrollToMostRecentComment: Bool
    private var composerFocus: ComposerFocusOnOpen
    private let origin: PostDetailNavigationOrigin
    private let hasFeaturedComment: Bool

    private var internalPost: OctopusCore.Post?

    /// Whether the screen is still loading the most recent end it opened on: every list published meanwhile is
    /// scrolled to its bottom.
    private var isLandingOnMostRecentEnd = false
    /// Whether the screen has reached the most recent end. Older comments load only after: the top of the list is on
    /// screen while it opens, and must not page in comments the member did not scroll to.
    private var hasLandedOnMostRecentEnd = false
    /// The pages of older comments loaded from the top of the most recent end, one at a time.
    private var olderPages = OlderPagesPacing()
    private var newerCommentsLoaderVisible = false
    /// Whether a page of newer comments is loading below the window the screen opened on: one at a time.
    private var isLoadingNewerComments = false
    /// Whether the window listed had newer comments to page in below it when it was listed: its laid out part then
    /// ends above them, and they stay lazy once they are all listed (see `MostRecentWindow.laidOutEnd`).
    private var windowPagesNewerComments = false
    /// Whether the screen asked the server for the window around the comment it opened on.
    private var hasOpenedOnComment = false
    private var newestListedCommentId: String?

    /// Whether the newest comment of the most recent end is on screen. Its row is laid out at once with the rest of
    /// the window: its `onAppear` fires as soon as the window is, even far below the screen.
    private var newestCommentOnScreen = false
    /// Whether the screen is displayed, between `onAppear()` and `onDisappear()`. The newest comments are polled only
    /// then: on the most recent end the poll follows where the newest comment is in the scroll view, which does not
    /// change when a pushed screen or another tab hides this one.
    private var isDisplayed = false
    private var additionalDataToFetch: CurrentValueSubject<Set<String>, Never> = .init([])

    private var storage = [AnyCancellable]()
    private var hasFetchedPostOnce = false

    private var relativeDateFormatterProvider: RelativeDateTimeFormatterProvider

    private var postOpenedOrigin: PostOpenedOrigin {
        switch origin {
        case .clientApp: .clientApp
        case .sdk: .sdk(hasFeaturedComment: hasFeaturedComment)
        }
    }

    init(octopus: OctopusSDK, mainFlowPath: MainFlowPath, translationStore: ContentTranslationPreferenceStore,
         postUuid: String, commentToScrollTo: String?,
         scrollToMostRecentComment: Bool,
         comment: Bool,
         origin: PostDetailNavigationOrigin,
         hasFeaturedComment: Bool) {
        self.octopus = octopus
        self.postUuid = postUuid
        self.scrollTarget = PendingScrollTarget(id: commentToScrollTo)
        // A comment to open on takes precedence over the most recent end, for good: a later emission of the post
        // must not switch the screen to the most recent end once the comment is shown.
        self.scrollToMostRecentComment = scrollToMostRecentComment && commentToScrollTo == nil
        self.composerFocus = ComposerFocusOnOpen(requested: comment,
                                                 opensOnMostRecentEnd: self.scrollToMostRecentComment)
        self.origin = origin
        self.hasFeaturedComment = hasFeaturedComment
        self.translationStore = translationStore
        connectedActionChecker = ConnectedActionChecker(octopus: octopus)
        relativeDateFormatterProvider = RelativeDateTimeFormatterProvider(octopus: octopus)

        self.internalPost = try? octopus.core.postsRepository.getPost(uuid: postUuid)

        Publishers.CombineLatest4(
            octopus.core.postsRepository.getPost(uuid: postUuid).removeDuplicates(),
            octopus.core.topicsRepository.$topics.removeDuplicates(),
            octopus.core.profileRepository.profilePublisher.removeDuplicates(),
            octopus.core.configRepository.communityConfigPublisher
                .map { $0?.gamificationConfig?.gamificationLevels }
                .removeDuplicates())
        .sink { [unowned self] post, topics, profile, gamificationLevels in
            self.internalPost = post
            guard postDeletion == nil else { return }
            guard let post else {
                // if post was not nil and is now nil, it has been deleted, or the logout emptied the cache
                let disappearedPost = self.post
                self.post = nil
                self.comments = nil
                self.lockedState = .unlocked

                if let disappearedPost {
                    confirmPostDisappearance(hasVideo: disappearedPost.hasVideo)
                }
                return
            }

            guard post.canBeDisplayed else {
                self.post = nil
                self.comments = nil
                self.lockedState = .unlocked
                postNotAvailable = true
                postDisappeared = true
                return
            }

            let topic = topics.first(where: { $0.uuid == post.parentId })

            let isOwnPost: Bool
            if let authorId = post.author?.uuid, let currentUserId = profile?.id {
                isOwnPost = authorId == currentUserId
            } else {
                isOwnPost = false
            }
            let resolvedLockedState = LockedContentState(
                permissions: post.permissions, isOwnContent: isOwnPost)
            self.lockedState = resolvedLockedState

            if resolvedLockedState == .lockedOther {
                self.post = nil
                self.comments = nil
                postNotAvailable = true
                return
            }

            self.post = Post(from: post,
                             gamificationLevels: gamificationLevels ?? [],
                             thisUserProfileId: profile?.id, topic: topic,
                             dateFormatter: relativeDateFormatterProvider.contentDateFormatter)
            newestFirstCommentsFeed = post.newestFirstCommentsFeed
            // `self`: the initializer's parameter of the same name would be read instead.
            if self.scrollToMostRecentComment, scrollTarget.id == nil, let newestFirstCommentsFeed {
                self.scrollToMostRecentComment = false
                openOnMostRecentEnd(feed: newestFirstCommentsFeed)
            } else if !hasOpenedOnComment, let commentId = scrollTarget.id, let newestFirstCommentsFeed,
                      let oldestFirstCommentsFeed = post.oldestFirstCommentsFeed {
                hasOpenedOnComment = true
                openOnComment(commentId, newestFirstFeed: newestFirstCommentsFeed, fallback: oldestFirstCommentsFeed)
            } else if !listsMostRecentEnd, let oldestFirstCommentsFeed = post.oldestFirstCommentsFeed {
                set(feed: oldestFirstCommentsFeed)
            }

        }.store(in: &storage)

        Publishers.CombineLatest3(
            $modelComments.removeDuplicates(),
            octopus.core.profileRepository.profilePublisher.removeDuplicates(),
            octopus.core.configRepository.communityConfigPublisher
                .map { $0?.gamificationConfig?.gamificationLevels }
                .removeDuplicates()
        )
        .sink { [unowned self] comments, profile, gamificationLevels in
            guard let comments else {
                self.comments = nil
                return
            }
            let commentsCount = comments.count
            let newComments = comments.enumerated().compactMap { [unowned self] idx, comment -> DisplayableFeedResponse? in
                guard comment.canBeDisplayed else { return nil }
                let onAppearAction: () -> Void
                let onDisappearAction: () -> Void
                // The window of the most recent end always ends on the newest comment, older ones still to load or not
                if (listsMostRecentEnd || !hasMoreData) && idx == commentsCount - 1 {
                    if #available(iOS 14, *) {
                        Logger.comments.trace("Setting autorefresh actions on \(String(describing: comment.text))")
                    }
                    // The most recent end lays its newest comment out at once: its `onAppear` fires even far below the
                    // screen and its `onDisappear` never does. The poll then follows `newestCommentOnScreenChanged`.
                    onAppearAction = { [weak self] in
                        guard let self else { return }
                        if !listsMostRecentEnd {
                            if #available(iOS 14, *) {
                                Logger.comments.trace("Will start autorefresh comments list: latest comment displayed")
                            }
                            shouldFetchLatestComments.send(true)
                        }
                        queueFetchAdditionalData(id: comment.uuid)
                    }
                    onDisappearAction = { [weak self] in
                        guard let self else { return }
                        if !listsMostRecentEnd {
                            if #available(iOS 14, *) {
                                Logger.comments.trace("Will stop autorefresh comments list: latest comment hidden")
                            }
                            shouldFetchLatestComments.send(false)
                        }
                        dequeueFetchAdditionalData(id: comment.uuid)
                    }
                } else if !listsMostRecentEnd, idx == max(commentsCount - 10, 0), hasMoreData {
                    if #available(iOS 14, *) {
                        Logger.comments.trace("Setting autorefresh actions on \(String(describing: comment.text))")
                    }
                    onAppearAction = { [weak self] in
                        guard let self else { return }
                        if !hideLoadMoreCommentsLoader {
                            if #available(iOS 14, *) {
                                Logger.comments.trace("Will refresh comments list due to trigger")
                            }
                            loadPreviousComments()
                        }
                        queueFetchAdditionalData(id: comment.uuid)
                    }
                    onDisappearAction = { [weak self] in
                        self?.dequeueFetchAdditionalData(id: comment.uuid)
                    }
                } else {
                    onAppearAction = { [weak self] in
                        self?.queueFetchAdditionalData(id: comment.uuid)
                    }
                    onDisappearAction = { [weak self] in
                        self?.dequeueFetchAdditionalData(id: comment.uuid)
                    }
                }

                let liveMeasurePublisher: CurrentValueSubject<LiveMeasures, Never>
                if let existingPublisher = liveMeasures[comment.uuid] {
                    liveMeasurePublisher = existingPublisher
                } else {
                    let newPublisher = CurrentValueSubject<LiveMeasures, Never>(
                        LiveMeasures(aggregatedInfo: .empty, userInteractions: .empty))
                    liveMeasurePublisher = newPublisher
                    liveMeasures[comment.uuid] = newPublisher
                }
                liveMeasurePublisher.send(LiveMeasures(aggregatedInfo: comment.aggregatedInfo, userInteractions: comment.userInteractions))
                return DisplayableFeedResponse(
                    from: comment, gamificationLevels: gamificationLevels ?? [],
                    liveMeasurePublisher: liveMeasurePublisher,
                    thisUserProfileId: profile?.id, dateFormatter: relativeDateFormatterProvider.contentDateFormatter,
                    onAppearAction: onAppearAction, onDisappearAction: onDisappearAction)
            }
            if newComments.isEmpty {
                shouldFetchLatestComments.send(true)
            } else if !newComments.isEmpty && (self.comments?.isEmpty ?? true) {
                shouldFetchLatestComments.send(false)
            }
            if self.comments != newComments {
                self.comments = newComments
                scrollToTargetIfListed()
                if listsMostRecentEnd { followMostRecentEnd(comments: newComments) }
                if #available(iOS 14, *) { Logger.comments.trace("Comments list updated done") }
            }
        }.store(in: &storage)

        fetchPost(incrementViewCount: true)
        fetchTopics()

        // When scrollToBottom completes (true → false) and focus is pending, focus the comment input
        $scrollToBottom
            .dropFirst()
            .removeDuplicates()
            .filter { !$0 }
            .sink { [unowned self] _ in
                if hidesListUntilLanded || landsWithoutAnimation { revealLandedList() }
                if composerFocus.scrollToBottomEnded() { focusComposer() }
            }.store(in: &storage)

        // When comments load but no scroll is pending, focus immediately
        $comments
            .removeDuplicates()
            .filter { $0 != nil }
            .sink { [unowned self] _ in
                if composerFocus.responsesListed(scrollRunning: scrollToBottom) { focusComposer() }
            }.store(in: &storage)

        octopus.core.commentsRepository.commentSentPublisher
            .sink { [unowned self] comment in
                guard comment.parentId == postUuid else { return }
                // refresh automatically when the comment is created
                if let newestFirstCommentsFeed {
                    showMostRecentEnd(afterSending: comment.uuid, feed: newestFirstCommentsFeed)
                } else {
                    hideLoadMoreCommentsLoader = true
                    loadAllComments(scrollToBottom: true)
                    scrollToBottom = true
                }
            }.store(in: &storage)

        octopus.core.profileRepository.onCurrentUserProfileUpdated.sink { [unowned self] _ in
            fetchPost()
            refreshFeed()
            fetchTopics()
        }.store(in: &storage)

        // A post kept through a closure of the community: the closure blocked the check of its vanishing, which left
        // the screen on its failure state. The reopening clears the displayed content: the screen asks again.
        octopus.core.sdkEventsEmitter.internalEvents
            .filter(\.clearedDisplayedContent)
            .sink { [unowned self] _ in
                guard VanishedContentCheck.asksAgainOnClearedContent(contentShown: post != nil,
                                                                    loadFailure: contentLoadFailure) else { return }
                retryFirstLoad()
            }.store(in: &storage)

        mainFlowPath.$path
            .prepend([])
            .zip(mainFlowPath.$path)
            .sink { [unowned self] previous, current in
                if case .currentUserProfile = previous.last,
                   case let .postDetail(postId, _, _, _, _, _) = current.last,
                   postId == postUuid {
                    // refresh automatically when the user profile is dismissed
                    fetchPost()
                    fetchTopics()
                }
            }.store(in: &storage)

        /// Reload post when app moves to foreground
        NotificationCenter.default
            .publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [unowned self] _ in
                fetchPost(incrementViewCount: true)
                fetchTopics()
                if isDisplayed && shouldFetchLatestComments.value {
                    startAutoFetchLatestComments()
                }
            }
            .store(in: &storage)

        NotificationCenter.default
            .publisher(for: UIApplication.willResignActiveNotification)
            .sink { [unowned self] _ in
                stopAutoFetchLatestComments()
            }
            .store(in: &storage)

        shouldFetchLatestComments
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [unowned self] shouldFetchLatestComments in
                if shouldFetchLatestComments && isDisplayed && UIApplication.shared.applicationState != .background {
                    startAutoFetchLatestComments()
                } else if !shouldFetchLatestComments {
                    stopAutoFetchLatestComments()
                }
            }.store(in: &storage)

        additionalDataToFetch
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .sink { [unowned self] in
                guard !$0.isEmpty else { return }
                let additionalDataToFetch = Array(additionalDataToFetch.value)
                Task {
                    do {
                        try await octopus.core.commentsRepository.fetchAdditionalData(ids: additionalDataToFetch,
                                                                                      incrementViewCount: false)
                    } catch {
                        if let error = error as? ServerCallError, case .serverError(.notAuthenticated) = error {
                            self.error = error.displayableMessage
                        }
                    }
                }
                self.additionalDataToFetch.send([])
            }
            .store(in: &storage)
    }

    func onDisappear() {
        isDisplayed = false
        stopAutoFetchLatestComments()
    }

    func onAppear() {
        isDisplayed = true
        if shouldFetchLatestComments.value {
            startAutoFetchLatestComments()
        }
        // update the child count and view number when the view is displayed
        Task {
            do {
                try await octopus.core.postsRepository.fetchAdditionalData(ids: [(postUuid, post?.hasVideo ?? false)],
                                                                           incrementViewCount: false)
            } catch {
                if let error = error as? ServerCallError, case .serverError(.notAuthenticated) = error {
                    self.error = error.displayableMessage
                }
            }
        }
    }

    func displayClientObject(clientObjectId: String) {
        guard let callback = octopus.displayClientObjectCallback else {
            error = .unknownError
            return
        }

        do {
            try callback(clientObjectId)
            octopus.core.trackingRepository.trackClientObjectOpenedFromBridge()
        } catch {
            self.error = .unknownError
        }
    }

    /// Scrolls to the comment the screen opened on, once it is listed and its load has settled.
    private func scrollToTargetIfListed() {
        guard let id = scrollTarget.takeIfListed(comments?.map(\.uuid) ?? []) else { return }
        let anchorId = ResponseKind.comment.scrollAnchorId(for: id)
        guard listsMostRecentEnd else {
            scrollToId = anchorId
            return
        }
        // The window around the comment is a lazy stack's child, whose rows the stack does not reach until it has
        // built it: the scroll goes through the window first, then to the comment once the window is built.
        scrollRequest = Compat.ScrollRequest(id: anchorId, anchor: .bottom,
                                             fallbackId: ResponseKind.comment.laidOutPartScrollAnchorId)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.scrollToId = anchorId
        }
    }

    private func set(feed: Feed<Comment, Never>) {
        guard feed.id != self.feed?.id else { return }
        // Started before subscribing: a feed that already holds the comment publishes it at once, and a scroll
        // then would be undone as the load below replaces those items.
        scrollTarget.loadStarted()
        comments = nil
        self.feed = feed
        feedStorage = []

        // Every value, duplicates included: the stored items and the server's first page can be the same, the end of the
        // thread being known only with the second one (see `OldestFirstThread.listed`).
        feed.$items
            .sink { [unowned self, weak feed] in
                guard let feed else { return }
                modelComments = merge(oldestFirstCommentsFeedItems: $0, of: feed,
                                      newestFirstCommentsFeedItems: newestFirstCommentsFeed?.items ?? [])
            }.store(in: &feedStorage)

        feed.$hasMoreData
            .removeDuplicates()
            .sink { [unowned self] in
                if #available(iOS 14, *) { Logger.comments.trace("Feed has more data: \($0)") }
                hasMoreData = $0
            }.store(in: &feedStorage)

        guard let loadUntil = scrollTarget.id else {
            Task {
                await feed.populateWithLocalData(pageSize: 10)
            }
            if scrollToMostRecentComment {
                loadAllComments(scrollToBottom: true)
                scrollToMostRecentComment = false
            } else {
                refreshFeed()
            }
            return
        }
        listsDownToTargetComment = true
        // The local first page replaces whatever the feed already holds, so the load until the comment runs after it.
        Task {
            await feed.populateWithLocalData(pageSize: 10)
            await loadAllComments(until: loadUntil, in: feed)
            // A newer feed set meanwhile runs its own load: only that one settles the target.
            guard self.feed?.id == feed.id else { return }
            scrollTarget.loadSettled()
            scrollToTargetIfListed()
        }
    }

    /// Opens the screen on the comment it targets with the window of the thread around it, listed like the most recent
    /// end, instead of every comment down to it: a long thread is then never loaded nor laid out whole. Older comments
    /// load from its top, newer ones from its bottom. The window is a feed of this screen's own, so no other screen nor
    /// the stored newest comments ever list it. When the server cannot open the thread on the comment, the stored
    /// comments are listed, then every comment down to it, oldest first.
    private func openOnComment(_ commentId: String, newestFirstFeed: Feed<Comment, Never>,
                               fallback: Feed<Comment, Never>) {
        scrollTarget.loadStarted()
        comments = nil
        let feed = newestFirstFeed.makeWindow(anchoredOn: commentId)
        listMostRecentEnd(of: feed)
        Task {
            let isAnchored: Bool
            do {
                isAnchored = try await feed.openWindow(pageSize: MostRecentWindow.initialSize)
            } catch {
                if #available(iOS 14, *) { Logger.comments.debug("Error while opening on the comment: \(error)") }
                isAnchored = false
            }
            // A comment sent meanwhile listed the most recent end instead: the window is no longer on screen.
            guard self.feed?.id == feed.id else { return }
            guard isAnchored else {
                stopAutoFetchLatestComments()
                listsMostRecentEnd = false
                listedWindowId = nil
                hasNewerComments = false
                set(feed: fallback)
                return
            }
            hasLoadedComments = true
            commentsLoadFailure = nil
            // Let the window publish before scrolling to the comment.
            DispatchQueue.main.async {
                self.scrollTarget.loadSettled()
                self.scrollToTargetIfListed()
                self.mostRecentEndReached()
            }
        }
    }

    /// Opens the screen on the most recent end of the thread: the local window first, then the server's, each landed
    /// on its newest comment. The whole thread is never loaded.
    private func openOnMostRecentEnd(feed: Feed<Comment, Never>) {
        comments = nil
        isLandingOnMostRecentEnd = true
        // iOS 13 has no scroll to the bottom whose end would show the list again
        if #available(iOS 14, *) {
            hidesListUntilLanded = true
            landsWithoutAnimation = true
        }
        listMostRecentEnd(of: feed)
        Task {
            await feed.populateWithLocalData(pageSize: MostRecentWindow.initialSize)
            if feed.items?.isEmpty ?? true { hidesListUntilLanded = false }
            await refreshFeed()
            // Let the refreshed items publish before the landing ends.
            DispatchQueue.main.async {
                self.isLandingOnMostRecentEnd = false
                let landingEnd = self.composerFocus.landingEnded(hasListedResponses: !(self.comments?.isEmpty ?? true))
                if landingEnd.scrollsToBottom {
                    self.scrollToBottom = true
                    // the end of that scroll shows the list; never leave it hidden if the scroll does not happen
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.endLanding() }
                } else {
                    self.endLanding()
                }
                if landingEnd.focusesComposer { self.focusComposer() }
                self.mostRecentEndReached()
            }
        }
    }

    /// Shows the most recent end of the thread once the member sent a comment, so the comment is listed without
    /// loading the whole thread.
    private func showMostRecentEnd(afterSending commentId: String, feed: Feed<Comment, Never>) {
        olderPages.forgetKeptResponse()
        // The window shrinks back and its top may cross the screen before it is scrolled to its bottom again: older
        // ones load only once it is there.
        hasLandedOnMostRecentEnd = false
        if self.feed?.id != feed.id {
            // The comments listed so far stay until the window is loaded, instead of flashing a loader. The screen
            // scrolls once it is: the bottom of the comments listed so far may be lazy rows, and a lazy stack of rows
            // of different heights, scrolled to its bottom while the keyboard goes down, can loop in its layout.
            listMostRecentEnd(of: feed)
        } else {
            // The window is laid out down to its bottom: the screen goes there at once.
            scrollToBottom = true
        }
        Task {
            do {
                // The window shrinks back to its first size: the member is at its bottom, writing.
                try await feed.refreshWhenIdle(pageSize: MostRecentWindow.initialSize)
                // More responses than the window holds may have been posted meanwhile: load down to the sent one, which
                // its composer waits for. It is among the newest, so this loads nothing more in the usual case.
                try await feed.fetchAll(until: commentId)
            } catch {
                if #available(iOS 14, *) { Logger.comments.debug("Error while refreshing after sending: \(error)") }
            }
            DispatchQueue.main.async {
                self.scrollToBottom = true
                self.mostRecentEndReached()
            }
        }
    }

    /// Lists the window of the newest comments, oldest at the top, in place of the comments listed so far.
    private func listMostRecentEnd(of feed: Feed<Comment, Never>) {
        stopAutoFetchLatestComments()
        listsMostRecentEnd = true
        hideLoadMoreCommentsLoader = false
        hasLandedOnMostRecentEnd = false
        newestListedCommentId = nil
        windowPagesNewerComments = false
        self.feed = feed
        feedStorage = []

        let windowId = feed.id
        feed.$items
            .removeDuplicates()
            .sink { [unowned self] in
                // Nil until the feed has loaded: whatever is listed stays until then.
                guard let items = $0 else { return }
                if listedWindowId != windowId { listedWindowId = windowId }
                modelComments = MostRecentWindow.displayOrder(newestFirst: items)
            }.store(in: &feedStorage)

        feed.$hasMoreData
            .removeDuplicates()
            .sink { [unowned self] in
                if #available(iOS 14, *) { Logger.comments.trace("Feed has more data: \($0)") }
                hasMoreData = $0
            }.store(in: &feedStorage)

        feed.$hasNewerData
            .removeDuplicates()
            .sink { [unowned self] in
                hasNewerComments = $0
                if $0 { windowPagesNewerComments = true }
            }
            .store(in: &feedStorage)

        if isDisplayed && shouldFetchLatestComments.value {
            startAutoFetchLatestComments()
        }
    }

    /// Keeps the screen on the most recent end as the window changes: on its bottom while it lands and whenever a newer
    /// comment appears under the member's eyes, and on the same comment when older ones are inserted above.
    private func followMostRecentEnd(comments: [DisplayableFeedResponse]) {
        let previousNewestId = newestListedCommentId
        newestListedCommentId = comments.last?.uuid
        let step = MostRecentWindow.follow(
            ids: comments.map(\.uuid), previousNewestId: previousNewestId,
            previousNewestVisible: previousNewestId != nil && newestCommentOnScreen,
            previousFirstId: olderPages.keptIdAwaitingListing, landing: isLandingOnMostRecentEnd,
            pagesNewer: windowPagesNewerComments)
        if let keptId = step.rowKeptInPlace {
            perform(olderPages.pageListed(keepingInPlace: keptId))
        }
        if step.scrollsToBottom {
            DispatchQueue.main.async {
                self.scrollToBottom = true
            }
        }
    }

    /// Shows the list once the scroll that lands it on its bottom has been laid out. The next scrolls are animated
    /// once it landed on the server's window.
    private func revealLandedList() {
        let landed = !isLandingOnMostRecentEnd
        DispatchQueue.main.async {
            self.hidesListUntilLanded = false
            if landed { self.endLanding() }
        }
    }

    private func endLanding() {
        if hidesListUntilLanded { hidesListUntilLanded = false }
        if landsWithoutAnimation { landsWithoutAnimation = false }
    }

    private func focusComposer() {
        commentTextFocused = true
        // Delay the second scroll to wait for the keyboard appearance animation, so the scroll
        // targets the reduced visible area rather than the full pre-keyboard layout.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.66) {
            self.scrollToBottom = true
        }
    }

    /// Called once the screen scrolled to the most recent end: older comments may load from now on, at once if the
    /// top of a short window is already on screen.
    private func mostRecentEndReached() {
        // Past the scroll animation, during which the rows it crosses appear.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.hasLandedOnMostRecentEnd = true
            self.loadOlderCommentsIfLoaderVisible()
            self.loadNewerCommentsIfLoaderVisible()
        }
    }

    private func loadOlderCommentsIfLoaderVisible() {
        perform(olderPages.nextPage(canLoad: canLoadOlderComments))
    }

    /// Called when the loader of older comments, at the top of the most recent end, leaves the screen.
    func previousCommentsLoaderDisappeared() {
        olderPages.loaderLeftScreen()
    }

    /// Whether a page of older comments may load: only once the screen reached the most recent end (see
    /// `hasLandedOnMostRecentEnd`).
    private var canLoadOlderComments: Bool {
        listsMostRecentEnd && hasLandedOnMostRecentEnd && hasMoreData
    }

    private func perform(_ action: OlderPagesPacing.Action) {
        switch action {
        case .none:
            break
        case .loadPage:
            loadOlderComments()
        case let .keepInPlace(keptId):
            DispatchQueue.main.async {
                self.scrollRequest = Compat.ScrollRequest(
                    id: ResponseKind.comment.scrollAnchorId(for: keptId), anchor: .top, animated: false,
                    // Before older pages are inserted, the response at the top of the window is the first one of the
                    // laid out part, out of the scroll view's reach (see `ScrollRequest.fallbackId`).
                    fallbackId: ResponseKind.comment.laidOutPartScrollAnchorId)
            }
            let generation = olderPages.generation
            DispatchQueue.main.asyncAfter(deadline: .now() + OlderPagesPacing.keepInPlaceTimeout) { [weak self] in
                guard let self else { return }
                perform(olderPages.timedOut(generation: generation, canLoad: canLoadOlderComments))
            }
        }
    }

    /// Loads the page of comments older than the most recent end's window, kept in place above the comment at its top.
    private func loadOlderComments() {
        guard let feed else { return }
        olderPages.pageRequested(keptId: comments?.first?.uuid)
        let generation = olderPages.generation
        Task { [self] in
            do {
                try await feed.loadPreviousItems(pageSize: MostRecentWindow.olderPageSize)
            } catch {
                if #available(iOS 14, *) { Logger.comments.debug("Error while loading older comments: \(error)") }
                if let error = error as? ServerCallError, case .serverError(.notAuthenticated) = error {
                    self.error = error.displayableMessage
                }
                olderPages.pageFailed()
                return
            }
            // The page lists nothing above the window when the feed ignored the call, or when its comments were all
            // listed already: the next one may load then.
            DispatchQueue.main.asyncAfter(deadline: .now() + OlderPagesPacing.listingTimeout) { [weak self] in
                guard let self else { return }
                perform(olderPages.timedOut(generation: generation, canLoad: canLoadOlderComments))
            }
        }
    }

    /// Called as the newest comment of the most recent end enters or leaves the screen: a newer one is followed only
    /// when it was on screen, and the newest comments are polled only while it is.
    func newestCommentOnScreenChanged(_ onScreen: Bool) {
        newestCommentOnScreen = onScreen
        if listsMostRecentEnd {
            shouldFetchLatestComments.send(onScreen)
        }
    }

    /// Called when the loader of newer comments, below the window the screen opened on, is on screen: loads them once
    /// the screen has scrolled to the comment it opened on.
    func loadNewerComments() {
        newerCommentsLoaderVisible = true
        guard let feed, hasNewerComments, hasLandedOnMostRecentEnd, !isLoadingNewerComments else { return }
        isLoadingNewerComments = true
        Task {
            do {
                try await feed.loadNewerItems()
            } catch {
                if #available(iOS 14, *) { Logger.comments.debug("Error while loading newer comments: \(error)") }
                if let error = error as? ServerCallError, case .serverError(.notAuthenticated) = error {
                    self.error = error.displayableMessage
                }
                isLoadingNewerComments = false
                return
            }
            // Once the page is listed: a page too short to push the loader away loads the next one.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isLoadingNewerComments = false
                self.loadNewerCommentsIfLoaderVisible()
            }
        }
    }

    /// Called when the loader of newer comments, below the window the screen opened on, leaves the screen.
    func newerCommentsLoaderDisappeared() {
        newerCommentsLoaderVisible = false
    }

    private func loadNewerCommentsIfLoaderVisible() {
        guard listsMostRecentEnd, newerCommentsLoaderVisible, hasNewerComments else { return }
        loadNewerComments()
    }

    /// Called when the member closes the nickname choice screen without confirming their nickname: forwarded to
    /// the composer, which drops the contribution it held.
    func nicknameChoiceClosed() {
        nicknameChoiceClosedSubject.send()
    }

    /// Emits when the member closes the nickname choice screen without confirming their nickname. The composer,
    /// whose view model this one does not own, listens to it alongside ``ensureConnected(action:)``.
    var nicknameChoiceClosedPublisher: AnyPublisher<Void, Never> {
        nicknameChoiceClosedSubject.eraseToAnyPublisher()
    }

    func ensureConnected(action: UserAction) -> Bool {
        return connectedActionChecker.ensureConnected(action: action, actionWhenNotConnected: authenticationActionBinding)
    }

    func refresh() async {
        let refreshPostTask = Task { await refreshPost() }
        let refreshTopicsTask = Task { try? await fetchTopics() }
        // The window the screen opened on is not refreshed: it would drop the pages the member loaded around it.
        let refreshCommentsTask = Task { if !hasNewerComments { await refreshFeed() } }
        await refreshPostTask.value
        await refreshTopicsTask.value
        await refreshCommentsTask.value
    }

    func deletePost() {
        postDeletion = .inProgress
        Task {
            await deletePost()
        }
    }

    func deleteComment(commentId: String) {
        isDeletingComment = true
        Task {
            await deleteComment(commentId: commentId)
            isDeletingComment = false
        }
    }

    private func startAutoFetchLatestComments() {
        guard autoFetchLatestCommentsTask == nil else {
            if #available(iOS 14, *) { Logger.comments.trace("startAutoFetchLatestComments called multiple times") }
            return
        }
        if listsMostRecentEnd, let feed {
            // The window is itself the newest comments: refreshing its newest page and keeping the older ones lists
            // the new ones in one server call, without dropping those the member paged in.
            autoFetchLatestCommentsTask = Task {
                repeat {
                    do {
                        try await feed.refreshNewestItems(
                            pageSize: MostRecentWindow.refreshSize(listedCount: feed.items?.count ?? 0))
                    } catch {
                        if let error = error as? ServerCallError, case .serverError(.notAuthenticated) = error {
                            self.error = error.displayableMessage
                        }
                    }
                    // A page of older comments asked for during the refresh was ignored.
                    loadOlderCommentsIfLoaderVisible()
                    try await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                } while (!Task.isCancelled)
            }
            return
        }
        guard let newestFirstCommentsFeed else { return }

        listenToNewestCommentsFeed()

        let oldestFirstFeed = feed
        autoFetchLatestCommentsTask = Task {
            repeat {
                do {
                    // The stored comments are listed alone while no page of the server lists the end of the thread,
                    // its first refresh having failed or been ignored: the newest comments polled are not added to
                    // them until then (see `OldestFirstThread.listed`). The thread is refreshed again first.
                    if let oldestFirstFeed, oldestFirstFeed.endsOnStoredItems, !scrollTarget.isLoading {
                        try await oldestFirstFeed.refresh(pageSize: 10)
                        commentsLoadFailure = nil
                    }
                    try await newestFirstCommentsFeed.refresh(pageSize: 10)
                } catch {
                    if let error = error as? ServerCallError, case .serverError(.notAuthenticated) = error {
                        self.error = error.displayableMessage
                    }
                }
                // wait for 5 seconds
                try await Task.sleep(nanoseconds: 5 * 1_000_000_000)
            } while (!Task.isCancelled)
        }
    }

    func loadAllComments(scrollToBottom: Bool) {
        guard let feed else { return }
        Task {
            defer { hasLoadedComments = true }
            do {
                try await feed.fetchAll()
                commentsLoadFailure = nil
            } catch {
                if #available(iOS 14, *) { Logger.comments.debug("Error: \(error)") }
                if comments?.isEmpty ?? true { commentsLoadFailure = ScreenStateFailure(error) }
            }
            if scrollToBottom {
                DispatchQueue.main.async {
                    self.hideLoadMoreCommentsLoader = true
                    self.scrollToBottom = true
                }
            }
        }
    }

    private func loadAllComments(until id: String, in feed: Feed<Comment, Never>) async {
        defer { hasLoadedComments = true }
        do {
            try await feed.fetchAll(until: id)
            commentsLoadFailure = nil
        } catch {
            if #available(iOS 14, *) { Logger.replies.debug("Error: \(error)") }
            if comments?.isEmpty ?? true { commentsLoadFailure = ScreenStateFailure(error) }
        }
    }

    private func listenToNewestCommentsFeed() {
        guard let newestFirstCommentsFeed else { return }
        autoFetchLatestCommentsCancellable = newestFirstCommentsFeed.$items
            .sink { [unowned self] in
                guard let newestComments = $0, let feed else { return }
                let newCommentList = merge(oldestFirstCommentsFeedItems: feed.items, of: feed,
                                           newestFirstCommentsFeedItems: newestComments)
                if newCommentList != modelComments {
                    modelComments = newCommentList
                    DispatchQueue.main.async {
                        self.scrollToBottom = true
                    }
                }
            }
    }

    /// The comments listed from the start of the thread, then the newest ones once `feed` reached its end (see
    /// `OldestFirstThread.listed`).
    private func merge(
        oldestFirstCommentsFeedItems: [Comment]?, of feed: Feed<Comment, Never>,
        newestFirstCommentsFeedItems: [Comment])
    -> [Comment]? {
        OldestFirstThread.listed(oldestFirst: oldestFirstCommentsFeedItems, reachedEnd: feed.hasReachedServerEnd,
                                 newestFirst: newestFirstCommentsFeedItems, id: \.uuid)
    }

    private func stopAutoFetchLatestComments() {
        autoFetchLatestCommentsTask?.cancel()
        autoFetchLatestCommentsTask = nil
        autoFetchLatestCommentsCancellable = nil
    }

    private func queueFetchAdditionalData(id: String) {
        var currentValue = additionalDataToFetch.value
        currentValue.insert(id)
        additionalDataToFetch.send(currentValue)
    }

    private func dequeueFetchAdditionalData(id: String) {
        var currentValue = additionalDataToFetch.value
        currentValue.remove(id)
        additionalDataToFetch.send(currentValue)
    }

    private func fetchPost(incrementViewCount: Bool = false) {
        Task {
            do {
                try await fetchPost(uuid: postUuid, incrementViewCount: incrementViewCount)
                contentLoadFailure = nil
            } catch {
                // Nothing on screen to keep: the failure takes the whole screen, with a retry. A toast
                // over an empty screen would leave a spinner spinning behind it (Screen states spec).
                if post == nil {
                    contentLoadFailure = ScreenStateFailure(error)
                } else if comments?.isEmpty == false,
                          let error = error as? ServerCallError, case .noNetwork = error {
                    // One error, one channel. Gated on the comments being on screen rather than on
                    // their failure being set: both fetches run concurrently, so testing the other's
                    // failure would report twice or not, depending on which lost the race.
                    octopus.core.toastsRepository.display(errorToast: .noNetwork)
                }
            }
        }
    }

    /// Re-runs the screen's first load, from the error state's CTA.
    func retryFirstLoad() {
        contentLoadFailure = nil
        fetchPost()
        refreshFeed()
    }

    private func fetchTopics() {
        Task {
            do {
                try await fetchTopics()
            } catch {
                if #available(iOS 14, *) {
                    Logger.posts.debug("Error while fetching the topics: \(error)")
                }
            }
        }
    }

    private func fetchPost(uuid: String, incrementViewCount: Bool) async throws(ServerCallError) {
        do {
            let hasVideo: Bool
            if let post {
                hasVideo = post.hasVideo
            } else {
                hasVideo = (try? await octopus.core.postsRepository.getPostValue(uuid: uuid)?.hasVideo) ?? false
            }
            try await octopus.core.postsRepository.fetchPost(uuid: postUuid, hasVideo: hasVideo,
                                                             incrementViewCount: incrementViewCount)
            if !hasFetchedPostOnce {
                let postOpenedOrigin: PostOpenedOrigin =
                switch origin {
                case .clientApp: .clientApp
                case .sdk: .sdk(hasFeaturedComment: hasFeaturedComment)
                }
                octopus.core.trackingRepository.trackPostOpened(origin: postOpenedOrigin, success: true)
            }
            hasFetchedPostOnce = true
        } catch {
            if !hasFetchedPostOnce {
                switch error {
                case .noNetwork: break // do not track a failure if the error was no network
                default:
                    let postOpenedOrigin: PostOpenedOrigin =
                    switch origin {
                    case .clientApp: .clientApp
                    case .sdk: .sdk(hasFeaturedComment: hasFeaturedComment)
                    }
                    octopus.core.trackingRepository.trackPostOpened(origin: postOpenedOrigin, success: false)
                }
            }
            hasFetchedPostOnce = true
            if case let .serverError(error) = error, case .notFound = error {
                postNotAvailable = true
            } else {
                throw error
            }
        }
    }

    private func fetchTopics() async throws {
        try await octopus.core.topicsRepository.fetchTopics()
    }

    /// Asks the server whether a post that vanished from the cache still exists: the logout purge also removes
    /// the posts of the previous session, which the next one may still see.
    private func confirmPostDisappearance(hasVideo: Bool) {
        Task {
            await confirmPostDisappearance(hasVideo: hasVideo)
        }
    }

    private func confirmPostDisappearance(hasVideo: Bool) async {
        let fetchError: ServerCallError?
        do {
            try await octopus.core.postsRepository.fetchPost(uuid: postUuid, hasVideo: hasVideo)
            fetchError = nil
        } catch {
            fetchError = error
        }
        switch VanishedContentCheck(fetchError: fetchError) {
        case .stillAvailable:
            // The comments went with the post.
            await refreshFeed()
        case .gone:
            postNotAvailable = true
            postDisappeared = true
        case let .unanswered(failure):
            contentLoadFailure = failure
        }
    }

    private func refreshFeed(scrollToTop: Bool = false) {
        Task {
            await refreshFeed(scrollToTop: scrollToTop)
        }
    }

    /// Re-runs the comments' first load after a failure.
    func retryCommentsFirstLoad() {
        commentsLoadFailure = nil
        // Hold the loader until the retry settles, instead of flashing the empty state through the gap.
        hasLoadedComments = false
        refreshFeed()
    }

    private func refreshPost() async {
        do {
            try await fetchPost(uuid: postUuid, incrementViewCount: false)
        } catch {
            self.error = error.displayableMessage
        }
    }

    private func refreshFeed(scrollToTop: Bool = false) async {
        guard let feed else { return }
        defer { hasLoadedComments = true }
        do {
            let pageSize = listsMostRecentEnd
                ? MostRecentWindow.refreshSize(listedCount: feed.items?.count ?? 0)
                : 10
            try await feed.refresh(pageSize: pageSize)
            commentsLoadFailure = nil
        } catch {
            if #available(iOS 14, *) { Logger.comments.debug("Error while refreshing posts feed: \(error)") }
            // No comment listed yet: the failure takes the list's place, with a retry (Screen states spec).
            if comments?.isEmpty ?? true {
                commentsLoadFailure = ScreenStateFailure(error)
            } else if case .serverError(.notAuthenticated) = error {
                self.error = error.displayableMessage
            } else if case .noNetwork = error {
                // Comments are already on screen: a toast says so without replacing them (Screen states spec).
                octopus.core.toastsRepository.display(errorToast: .noNetwork)
            } else {
                octopus.core.toastsRepository.display(errorToast: .unknown)
            }
        }
    }

    private func deletePost() async {
        do {
            try await octopus.core.postsRepository.deletePost(postId: postUuid)
            postDeletion = .done
        } catch {
            postDeletion = nil
            self.error = error.displayableMessage
        }
    }

    private func deleteComment(commentId: String) async {
        do {
            try await octopus.core.commentsRepository.deleteComment(commentId: commentId)
            commentDeleted = true
        } catch {
            self.error = error.displayableMessage
        }
    }

    func blockAuthor(profileId: String) {
        Task {
            await blockAuthor(profileId: profileId)
        }
    }

    private func blockAuthor(profileId: String) async {
        do {
            try await octopus.core.profileRepository.blockUser(profileId: profileId)
        } catch {
            self.error = error.displayableMessage
        }
    }

    /// Called when the loader at the end of the list is on screen. On the most recent end, the loader of older
    /// comments at its top came to rest on screen.
    func loadPreviousComments() {
        guard let feed else { return }
        if listsMostRecentEnd {
            perform(olderPages.loaderRestedOnScreen(canLoad: canLoadOlderComments))
            return
        }
        Task {
            do {
                try await feed.loadPreviousItems(pageSize: 50)
            } catch {
                if #available(iOS 14, *) { Logger.comments.debug("Error while loading posts feed previous items: \(error)") }
                if let error = error as? ServerCallError, case .serverError(.notAuthenticated) = error {
                   self.error = error.displayableMessage
               }
            }
        }
    }

    /// Casts the vote; returns whether it was cast, so the poll gives its options back otherwise.
    func vote(pollAnswerId: String) async -> Bool {
        guard ensureConnected(action: .vote) else { return false }
        guard let post = internalPost else {
            error = .unknownError
            return false
        }
        return await vote(pollAnswerId: pollAnswerId, post: post)
    }

    private func vote(pollAnswerId: String, post: OctopusCore.Post) async -> Bool {
        do {
            try await octopus.core.postsRepository.vote(
                pollAnswerId: pollAnswerId, post: post,
                parentIsTranslated: translationStore.displayTranslation(for: post.uuid))
            return true
        } catch {
            switch error {
            case let .validation(argumentError):
                // special case where the error missingParent is returned: reload the post to check that it has not been
                // deleted
                for error in argumentError.errors.values.flatMap({ $0 }) {
                    if case .missingParent = error.detail {
                        try? await octopus.core.postsRepository.fetchPost(uuid: post.uuid, hasVideo: post.hasVideo)
                        break
                    }
                }
                for (displayKind, errors) in argumentError.errors {
                    guard !errors.isEmpty else { continue }
                    let multiErrorLocalizedString = errors.map(\.localizedMessage).joined(separator: "\n- ")
                    switch displayKind {
                    case .alert:
                        self.error = .localizedString(multiErrorLocalizedString)
                    case let .linkedToField(field):
                        switch field {
                        }
                    }
                }
            case let .serverCall(serverError):
                self.error = serverError.displayableMessage
            case .other:
                self.error = .unknownError
            }
            return false
        }
    }

    func setReaction(_ reaction: ReactionKind?) {
        guard ensureConnected(action: .reaction) else { return }
        guard let post = internalPost else { return }
        Task {
            await set(reaction: reaction, post: post)
        }
    }

    func setCommentReaction(_ reaction: ReactionKind?, commentId: String) {
        guard ensureConnected(action: .reaction) else { return }
        // The listed comments, not the feed's: newer comments merged from the newest-first feed are listed too.
        guard let comment = modelComments?.first(where: { $0.id == commentId }) else {
            error = .unknownError
            return
        }
        Task {
            await set(reaction: reaction, comment: comment)
        }
    }

    private func set(reaction: ReactionKind?, post: OctopusCore.Post) async {
        do {
            try await octopus.core.postsRepository.set(
                reaction: reaction, post: post,
                parentIsTranslated: translationStore.displayTranslation(for: post.uuid))
        } catch {
            switch error {
            case let .validation(argumentError):
                // special case where the error missingParent is returned: reload the comment to check that it has not
                // been deleted
                for error in argumentError.errors.values.flatMap({ $0 }) {
                    if case .missingParent = error.detail {
                        try? await octopus.core.postsRepository.fetchPost(uuid: post.uuid, hasVideo: post.hasVideo)
                        break
                    }
                }
                for (displayKind, errors) in argumentError.errors {
                    guard !errors.isEmpty else { continue }
                    let multiErrorLocalizedString = errors.map(\.localizedMessage).joined(separator: "\n- ")
                    switch displayKind {
                    case .alert:
                        self.error = .localizedString(multiErrorLocalizedString)
                    case let .linkedToField(field):
                        switch field {
                        }
                    }
                }
            case let .serverCall(serverError):
                self.error = serverError.displayableMessage
            case .other:
                self.error = .unknownError
            }
        }
    }

    private func set(reaction: ReactionKind?, comment: Comment) async {
        do {
            try await octopus.core.commentsRepository.set(
                reaction: reaction, comment: comment,
                parentIsTranslated: translationStore.displayTranslation(for: comment.uuid))
        } catch {
            switch error {
            case let .validation(argumentError):
                // special case where the error missingParent is returned: reload the comment to check that it has not
                // been deleted
                for error in argumentError.errors.values.flatMap({ $0 }) {
                    if case .missingParent = error.detail {
                        try? await octopus.core.commentsRepository.fetchComment(uuid: comment.uuid)
                        break
                    }
                }
                for (displayKind, errors) in argumentError.errors {
                    guard !errors.isEmpty else { continue }
                    let multiErrorLocalizedString = errors.map(\.localizedMessage).joined(separator: "\n- ")
                    switch displayKind {
                    case .alert:
                        self.error = .localizedString(multiErrorLocalizedString)
                    case let .linkedToField(field):
                        switch field {
                        }
                    }
                }
            case let .serverCall(serverError):
                self.error = serverError.displayableMessage
            case .other:
                self.error = .unknownError
            }
        }
    }
}
