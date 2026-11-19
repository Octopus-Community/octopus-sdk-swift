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
class CommentDetailViewModel: ObservableObject {

    struct CommentDetail: Equatable {
        let uuid: String
        let parentId: String
        let text: TranslatableText?
        let image: ImageMedia?
        let author: Author
        let relativeDate: DisplayableDate
        let aggregatedInfo: AggregatedInfo
        let userInteractions: UserInteractions
        let canBeDeleted: Bool
        let canBeModerated: Bool
        let canBeBlockedByUser: Bool
        let canCreateChildren: Bool
    }

    enum CommentDeletion {
        case inProgress
        case done
    }

    @Published private(set) var comment: CommentDetail?
    @Published private(set) var error: DisplayableString?

    // Comments
    private var feedStorage = [AnyCancellable]()
    private var feed: Feed<Reply, Never>?

    @Published private(set) var replies: [DisplayableFeedResponse]?
    /// Set when the replies' first load fails with nothing listed yet.
    @Published private(set) var repliesLoadFailure: ScreenStateFailure?
    /// Set when the comment itself could not be loaded and none was cached. Without it the screen
    /// spins forever: the replies cannot load either, so nothing reports the failure.
    @Published private(set) var contentLoadFailure: ScreenStateFailure?
    /// Whether the replies' first load has settled. Replies come from the local store first, so an
    /// empty list before that means "still loading".
    @Published private(set) var hasLoadedReplies = false
    @Published var scrollToBottom = false
    @Published var scrollToId: String?
    @Published private(set) var hasMoreData = false
    @Published private(set) var hideLoadMoreRepliesLoader = false
    /// Whether the list shows the most recent end of the thread (see ``MostRecentWindow``): set when the screen opens
    /// on its newest replies or once a reply is sent, so a long thread is never loaded whole.
    @Published private(set) var listsMostRecentEnd = false
    /// Whether the list is hidden while it lands on the most recent end: its first layout is at its top, and showing it
    /// there would draw the oldest replies of the window for a frame before the jump to the newest one. Not when nothing
    /// is stored to land on: the comment then shows at once instead of waiting for the server.
    @Published private(set) var hidesListUntilLanded = false
    /// Whether the scrolls that land the list on its most recent end are not animated, until the one landing it on the
    /// server's window ended: animating them would scroll through the window, or from a stale stored window.
    @Published private(set) var landsWithoutAnimation = false
    @Published var scrollRequest: Compat.ScrollRequest?
    @Published private var modelReplies: [Reply]?
    private var autoFetchLatestRepliesTask: Task<Void, Swift.Error>?
    private var autoFetchLatestRepliesCancellable: AnyCancellable?

    @Published var commentDeletion: CommentDeletion?

    @Published var isDeletingReply = false
    @Published var replyDeleted = false

    /// Presents the "not available" alert, which closes the screen.
    @Published var commentNotAvailable = false
    /// Whether the server answered that the comment is gone or out of reach. Unlike the alert, it stays set: the
    /// screen shows "not available" only then, never while the comment is missing for another reason.
    @Published private(set) var commentConfirmedNotAvailable = false
    @Published var lockedState: LockedContentState = .unlocked

    private var shouldFetchLatestReplies = CurrentValueSubject<Bool, Never>(false)
    private var liveMeasures: [String: CurrentValueSubject<LiveMeasures, Never>] = [:]

    @Published var authenticationAction: ConnectedActionReplacement?
    var authenticationActionBinding: Binding<ConnectedActionReplacement?> {
        Binding(
            get: { self.authenticationAction },
            set: { self.authenticationAction = $0 }
        )
    }

    var thisUserProfileId: String? {
        octopus.core.profileRepository.profile?.id
    }

    let octopus: OctopusSDK
    let commentUuid: String
    let connectedActionChecker: ConnectedActionChecker
    private let nicknameChoiceClosedSubject = PassthroughSubject<Void, Never>()
    private let translationStore: ContentTranslationPreferenceStore
    private let languageRepository: LanguageRepository

    private var newestFirstRepliesFeed: Feed<Reply, Never>?
    private var reply: Bool
    /// The reply the screen opened on, until the screen has scrolled to it.
    private var scrollTarget: PendingScrollTarget
    /// Whether the screen opens on a reply. Its list is then built whole from the start: a lazy list has
    /// not built a row far below the fold yet, so a scroll to it would find nothing and be lost.
    let opensOnReply: Bool

    private var internalComment: Comment?

    /// Whether the screen is still loading the most recent end it opened on: every list published meanwhile is
    /// scrolled to its bottom.
    private var isLandingOnMostRecentEnd = false
    /// Whether the screen has reached the most recent end. Older replies load only after: the top of the list is on
    /// screen while it opens, and must not page in replies the member did not scroll to.
    private var hasLandedOnMostRecentEnd = false
    /// The pages of older replies loaded from the top of the most recent end, one at a time.
    private var olderPages = OlderPagesPacing()
    private var newestListedReplyId: String?

    /// Whether the newest reply of the most recent end is on screen. Its row is laid out at once with the rest of
    /// the window: its `onAppear` fires as soon as the window is, even far below the screen.
    private var newestReplyOnScreen = false
    /// Whether the screen is displayed, between `onAppear()` and `onDisappear()`. The newest replies are polled only
    /// then: on the most recent end the poll follows where the newest reply is in the scroll view, which does not
    /// change when a pushed screen or another tab hides this one.
    private var isDisplayed = false
    private var additionalDataToFetch: CurrentValueSubject<Set<String>, Never> = .init([])

    private var storage = [AnyCancellable]()

    private var relativeDateFormatterProvider: RelativeDateTimeFormatterProvider

    init(octopus: OctopusSDK,
         translationStore: ContentTranslationPreferenceStore,
         commentUuid: String, reply: Bool, replyToScrollTo: String?) {
        self.octopus = octopus
        self.languageRepository = octopus.core.languageRepository
        self.translationStore = translationStore
        self.commentUuid = commentUuid
        // A reply to open on takes precedence over the most recent end, for good: a later emission of the comment
        // must not switch the screen to the most recent end once the reply is shown.
        self.reply = reply && replyToScrollTo == nil
        self.scrollTarget = PendingScrollTarget(id: replyToScrollTo)
        self.opensOnReply = replyToScrollTo != nil
        connectedActionChecker = ConnectedActionChecker(octopus: octopus)

        relativeDateFormatterProvider = RelativeDateTimeFormatterProvider(octopus: octopus)

        Publishers.CombineLatest3(
            octopus.core.commentsRepository.getComment(uuid: commentUuid).removeDuplicates(),
            octopus.core.profileRepository.profilePublisher.removeDuplicates(),
            octopus.core.configRepository.communityConfigPublisher
                .map { $0?.gamificationConfig?.gamificationLevels }
                .removeDuplicates()
        ).sink { [unowned self] comment, profile, gamificationLevels in
            self.internalComment = comment
            guard commentDeletion == nil else { return }
            guard let comment else {
                // if comment was not nil and is now nil, it has been deleted, or the logout emptied the cache
                let commentDisappeared = self.comment != nil
                self.comment = nil
                self.replies = nil
                self.lockedState = .unlocked

                if commentDisappeared {
                    confirmCommentDisappearance()
                }
                return
            }

            guard comment.canBeDisplayed else {
                self.comment = nil
                self.replies = nil
                self.lockedState = .unlocked
                markCommentNotAvailable()
                return
            }

            let isOwnComment: Bool
            if let authorId = comment.author?.uuid, let currentUserId = profile?.id {
                isOwnComment = authorId == currentUserId
            } else {
                isOwnComment = false
            }
            let resolvedLockedState = LockedContentState(
                permissions: comment.permissions, isOwnContent: isOwnComment)
            self.lockedState = resolvedLockedState

            if resolvedLockedState == .lockedOther {
                self.comment = nil
                self.replies = nil
                markCommentNotAvailable()
                return
            }

            self.comment = CommentDetail(from: comment,
                                         gamificationLevels: gamificationLevels ?? [],
                                         thisUserProfileId: profile?.id,
                                         dateFormatter: relativeDateFormatterProvider.contentDateFormatter)
            newestFirstRepliesFeed = comment.newestFirstRepliesFeed
            // `self`: the initializer's parameter of the same name would be read instead.
            if self.reply, scrollTarget.id == nil, let newestFirstRepliesFeed {
                self.reply = false
                openOnMostRecentEnd(feed: newestFirstRepliesFeed)
            } else if !listsMostRecentEnd, let oldestFirstRepliesFeed = comment.oldestFirstRepliesFeed {
                set(feed: oldestFirstRepliesFeed)
            }

        }.store(in: &storage)

        Publishers.CombineLatest3(
            $modelReplies.removeDuplicates(),
            octopus.core.profileRepository.profilePublisher.removeDuplicates(),
            octopus.core.configRepository.communityConfigPublisher
                .map { $0?.gamificationConfig?.gamificationLevels }
                .removeDuplicates()
        )
        .sink { [unowned self] reply, profile, gamificationLevels in
            guard let reply else {
                self.replies = nil
                return
            }
            let repliesCount = reply.count
            let newReplies = reply.enumerated().compactMap { [unowned self] idx, reply -> DisplayableFeedResponse? in
                guard reply.canBeDisplayed else { return nil }
                let onAppearAction: () -> Void
                let onDisappearAction: () -> Void
                // The window of the most recent end always ends on the newest reply, older ones still to load or not
                if (listsMostRecentEnd || !hasMoreData) && idx == repliesCount - 1 {
                    if #available(iOS 14, *) {
                        Logger.replies.trace("Setting autorefresh actions on \(String(describing: reply.text))")
                    }
                    // The most recent end lays its newest reply out at once: its `onAppear` fires even far below the
                    // screen and its `onDisappear` never does. The poll then follows `newestReplyOnScreenChanged`.
                    onAppearAction = { [weak self] in
                        guard let self else { return }
                        if !listsMostRecentEnd {
                            if #available(iOS 14, *) {
                                Logger.replies.trace("Will start autorefresh replies list: latest reply displayed")
                            }
                            shouldFetchLatestReplies.send(true)
                        }
                        queueFetchAdditionalData(id: reply.uuid)
                    }
                    onDisappearAction = { [weak self] in
                        guard let self else { return }
                        if !listsMostRecentEnd {
                            if #available(iOS 14, *) {
                                Logger.replies.trace("Will stop autorefresh replies list: latest reply hidden")
                            }
                            shouldFetchLatestReplies.send(false)
                        }
                        dequeueFetchAdditionalData(id: reply.uuid)
                    }
                } else if !listsMostRecentEnd, idx == max(repliesCount - 10, 0), hasMoreData {
                    if #available(iOS 14, *) {
                        Logger.replies.trace("Setting autorefresh actions on \(String(describing: reply.text))")
                    }
                    onAppearAction = { [weak self] in
                        guard let self else { return }
                        if !hideLoadMoreRepliesLoader {
                            if #available(iOS 14, *) {
                                Logger.replies.trace("Will refresh replies list due to trigger")
                            }
                            loadPreviousReplies()
                        }
                        queueFetchAdditionalData(id: reply.uuid)
                    }
                    onDisappearAction = { [weak self] in
                        self?.dequeueFetchAdditionalData(id: reply.uuid)
                    }
                } else {
                    onAppearAction = { [weak self] in
                        self?.queueFetchAdditionalData(id: reply.uuid)
                    }
                    onDisappearAction = { [weak self] in
                        self?.dequeueFetchAdditionalData(id: reply.uuid)
                    }
                }

                let liveMeasurePublisher: CurrentValueSubject<LiveMeasures, Never>
                if let existingPublisher = liveMeasures[reply.uuid] {
                    liveMeasurePublisher = existingPublisher
                } else {
                    let newPublisher = CurrentValueSubject<LiveMeasures, Never>(
                        LiveMeasures(aggregatedInfo: .empty, userInteractions: .empty))
                    liveMeasurePublisher = newPublisher
                    liveMeasures[reply.uuid] = newPublisher
                }
                liveMeasurePublisher.send(LiveMeasures(aggregatedInfo: reply.aggregatedInfo, userInteractions: reply.userInteractions))
                return DisplayableFeedResponse(
                    from: reply,
                    gamificationLevels: gamificationLevels ?? [],
                    liveMeasurePublisher: liveMeasurePublisher,
                    thisUserProfileId: profile?.id, dateFormatter: relativeDateFormatterProvider.contentDateFormatter,
                    onAppearAction: onAppearAction, onDisappearAction: onDisappearAction)
            }
            if newReplies.isEmpty {
                shouldFetchLatestReplies.send(true)
            } else if !newReplies.isEmpty && (self.replies?.isEmpty ?? true) {
                shouldFetchLatestReplies.send(false)
            }
            if self.replies != newReplies {
                self.replies = newReplies
                scrollToTargetIfListed()
                if listsMostRecentEnd { followMostRecentEnd(replies: newReplies) }
                if #available(iOS 14, *) { Logger.comments.trace("Replies list updated done") }
            }
        }.store(in: &storage)

        fetchComment(incrementViewCount: true)

        octopus.core.repliesRepository.replySentPublisher
            .sink { [unowned self] reply in
                guard reply.parentId == commentUuid else { return }
                // refresh automatically when the reply is created
                if let newestFirstRepliesFeed {
                    showMostRecentEnd(afterSending: reply.uuid, feed: newestFirstRepliesFeed)
                } else {
                    hideLoadMoreRepliesLoader = true
                    loadAllReplies(scrollToBottom: true)
                    scrollToBottom = true
                }
            }.store(in: &storage)

        // The end of the landing scroll (true → false) shows the list it hid. The next scrolls are animated once it
        // landed on the server's window.
        $scrollToBottom
            .dropFirst()
            .removeDuplicates()
            .filter { !$0 }
            .sink { [unowned self] _ in
                guard hidesListUntilLanded || landsWithoutAnimation else { return }
                let landed = !isLandingOnMostRecentEnd
                DispatchQueue.main.async {
                    if self.hidesListUntilLanded { self.hidesListUntilLanded = false }
                    if landed { self.endLanding() }
                }
            }.store(in: &storage)

        octopus.core.profileRepository.onCurrentUserProfileUpdated.sink { [unowned self] _ in
            fetchComment()
            refreshFeed()
        }.store(in: &storage)

        // A comment kept through a closure of the community: the closure blocked the check of its vanishing, which
        // left the screen on its failure state. The reopening clears the displayed content: the screen asks again.
        octopus.core.sdkEventsEmitter.internalEvents
            .filter(\.clearedDisplayedContent)
            .sink { [unowned self] _ in
                guard VanishedContentCheck.asksAgainOnClearedContent(contentShown: comment != nil,
                                                                    loadFailure: contentLoadFailure) else { return }
                retryFirstLoad()
            }.store(in: &storage)

        /// Reload comment when app moves to foreground
        NotificationCenter.default
            .publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [unowned self] _ in
                fetchComment(incrementViewCount: true)
                if isDisplayed && shouldFetchLatestReplies.value {
                    startAutoFetchLatestReplies()
                }
            }
            .store(in: &storage)

        NotificationCenter.default
            .publisher(for: UIApplication.willResignActiveNotification)
            .sink { [unowned self] _ in
                stopAutoFetchLatestReplies()
            }
            .store(in: &storage)

        shouldFetchLatestReplies
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [unowned self] shouldFetchLatestReplies in
                if shouldFetchLatestReplies && isDisplayed && UIApplication.shared.applicationState != .background {
                    startAutoFetchLatestReplies()
                } else if !shouldFetchLatestReplies {
                    stopAutoFetchLatestReplies()
                }
            }.store(in: &storage)

        additionalDataToFetch
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .sink { [unowned self] in
                guard !$0.isEmpty else { return }
                let additionalDataToFetch = Array(additionalDataToFetch.value)
                Task {
                    do {
                        try await octopus.core.repliesRepository.fetchAdditionalData(ids: additionalDataToFetch,
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
        stopAutoFetchLatestReplies()
    }

    func onAppear() {
        isDisplayed = true
        if shouldFetchLatestReplies.value {
            startAutoFetchLatestReplies()
        }
    }

    /// Scrolls to the reply the screen opened on, once it is listed and its load has settled.
    private func scrollToTargetIfListed() {
        guard let id = scrollTarget.takeIfListed(replies?.map(\.uuid) ?? []) else { return }
        scrollToId = ResponseKind.reply.scrollAnchorId(for: id)
    }

    private func set(feed: Feed<Reply, Never>) {
        guard feed.id != self.feed?.id else { return }
        // Started before subscribing: a feed that already holds the reply publishes it at once, and a scroll
        // then would be undone as the load below replaces those items.
        scrollTarget.loadStarted()
        replies = nil
        self.feed = feed
        feedStorage = []

        // Every value, duplicates included: the stored items and the server's first page can be the same, the end of the
        // thread being known only with the second one (see `OldestFirstThread.listed`).
        feed.$items
            .sink { [unowned self, weak feed] in
                guard let feed else { return }
                modelReplies = merge(oldestFirstRepliesFeedItems: $0, of: feed,
                                     newestFirstRepliesFeedItems: newestFirstRepliesFeed?.items ?? [])
            }.store(in: &feedStorage)

        feed.$hasMoreData
            .removeDuplicates()
            .sink { [unowned self] in
                if #available(iOS 14, *) { Logger.replies.trace("Feed has more data: \($0)") }
                hasMoreData = $0
            }.store(in: &feedStorage)

        guard let loadUntil = scrollTarget.id else {
            Task {
                await feed.populateWithLocalData(pageSize: 10)
            }
            if reply {
                loadAllReplies(scrollToBottom: true)
                reply = false
            } else {
                refreshFeed()
            }
            return
        }
        // The local first page replaces whatever the feed already holds, so the load until the reply runs after it.
        Task {
            await feed.populateWithLocalData(pageSize: 10)
            await loadAllReplies(until: loadUntil, in: feed)
            // A newer feed set meanwhile runs its own load: only that one settles the target.
            guard self.feed?.id == feed.id else { return }
            scrollTarget.loadSettled()
            scrollToTargetIfListed()
        }
    }

    /// Opens the screen on the most recent end of the thread: the local window first, then the server's, each landed
    /// on its newest reply. The whole thread is never loaded.
    private func openOnMostRecentEnd(feed: Feed<Reply, Never>) {
        replies = nil
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
                if !(self.replies?.isEmpty ?? true) {
                    self.scrollToBottom = true
                    // the end of that scroll shows the list; never leave it hidden if the scroll does not happen
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.endLanding() }
                } else {
                    self.endLanding()
                }
                self.mostRecentEndReached()
            }
        }
    }

    private func endLanding() {
        if hidesListUntilLanded { hidesListUntilLanded = false }
        if landsWithoutAnimation { landsWithoutAnimation = false }
    }

    /// Shows the most recent end of the thread once the member sent a reply, so the reply is listed without loading
    /// the whole thread.
    private func showMostRecentEnd(afterSending replyId: String, feed: Feed<Reply, Never>) {
        olderPages.forgetKeptResponse()
        // The window shrinks back and its top may cross the screen before it is scrolled to its bottom again: older
        // ones load only once it is there.
        hasLandedOnMostRecentEnd = false
        if self.feed?.id != feed.id {
            // The replies listed so far stay until the window is loaded, instead of flashing a loader. The screen
            // scrolls once it is: the bottom of the replies listed so far may be lazy rows, and a lazy stack of rows
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
                try await feed.fetchAll(until: replyId)
            } catch {
                if #available(iOS 14, *) { Logger.replies.debug("Error while refreshing after sending: \(error)") }
            }
            DispatchQueue.main.async {
                self.scrollToBottom = true
                self.mostRecentEndReached()
            }
        }
    }

    /// Lists the window of the newest replies, oldest at the top, in place of the replies listed so far.
    private func listMostRecentEnd(of feed: Feed<Reply, Never>) {
        stopAutoFetchLatestReplies()
        listsMostRecentEnd = true
        hideLoadMoreRepliesLoader = false
        hasLandedOnMostRecentEnd = false
        newestListedReplyId = nil
        self.feed = feed
        feedStorage = []

        feed.$items
            .removeDuplicates()
            .sink { [unowned self] in
                // Nil until the feed has loaded: whatever is listed stays until then.
                guard let items = $0 else { return }
                modelReplies = MostRecentWindow.displayOrder(newestFirst: items)
            }.store(in: &feedStorage)

        feed.$hasMoreData
            .removeDuplicates()
            .sink { [unowned self] in
                if #available(iOS 14, *) { Logger.replies.trace("Feed has more data: \($0)") }
                hasMoreData = $0
            }.store(in: &feedStorage)

        if isDisplayed && shouldFetchLatestReplies.value {
            startAutoFetchLatestReplies()
        }
    }

    /// Keeps the screen on the most recent end as the window changes: on its bottom while it lands and whenever a newer
    /// reply appears under the member's eyes, and on the same reply when older ones are inserted above.
    private func followMostRecentEnd(replies: [DisplayableFeedResponse]) {
        let previousNewestId = newestListedReplyId
        newestListedReplyId = replies.last?.uuid
        let step = MostRecentWindow.follow(
            ids: replies.map(\.uuid), previousNewestId: previousNewestId,
            previousNewestVisible: previousNewestId != nil && newestReplyOnScreen,
            previousFirstId: olderPages.keptIdAwaitingListing, landing: isLandingOnMostRecentEnd)
        if let keptId = step.rowKeptInPlace {
            perform(olderPages.pageListed(keepingInPlace: keptId))
        }
        if step.scrollsToBottom {
            DispatchQueue.main.async {
                self.scrollToBottom = true
            }
        }
    }

    /// Called once the screen scrolled to the most recent end: older replies may load from now on, at once if the top
    /// of a short window is already on screen.
    private func mostRecentEndReached() {
        // Past the scroll animation, during which the rows it crosses appear.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.hasLandedOnMostRecentEnd = true
            self.loadOlderRepliesIfLoaderVisible()
        }
    }

    private func loadOlderRepliesIfLoaderVisible() {
        perform(olderPages.nextPage(canLoad: canLoadOlderReplies))
    }

    /// Called when the loader of older replies, at the top of the most recent end, leaves the screen.
    func previousRepliesLoaderDisappeared() {
        olderPages.loaderLeftScreen()
    }

    /// Whether a page of older replies may load: only once the screen reached the most recent end (see
    /// `hasLandedOnMostRecentEnd`).
    private var canLoadOlderReplies: Bool {
        listsMostRecentEnd && hasLandedOnMostRecentEnd && hasMoreData
    }

    private func perform(_ action: OlderPagesPacing.Action) {
        switch action {
        case .none:
            break
        case .loadPage:
            loadOlderReplies()
        case let .keepInPlace(keptId):
            DispatchQueue.main.async {
                self.scrollRequest = Compat.ScrollRequest(
                    id: ResponseKind.reply.scrollAnchorId(for: keptId), anchor: .top, animated: false,
                    // Before older pages are inserted, the response at the top of the window is the first one of the
                    // laid out part, out of the scroll view's reach (see `ScrollRequest.fallbackId`).
                    fallbackId: ResponseKind.reply.laidOutPartScrollAnchorId)
            }
            let generation = olderPages.generation
            DispatchQueue.main.asyncAfter(deadline: .now() + OlderPagesPacing.keepInPlaceTimeout) { [weak self] in
                guard let self else { return }
                perform(olderPages.timedOut(generation: generation, canLoad: canLoadOlderReplies))
            }
        }
    }

    /// Loads the page of replies older than the most recent end's window, kept in place above the reply at its top.
    private func loadOlderReplies() {
        guard let feed else { return }
        olderPages.pageRequested(keptId: replies?.first?.uuid)
        let generation = olderPages.generation
        Task { [self] in
            do {
                try await feed.loadPreviousItems(pageSize: MostRecentWindow.olderPageSize)
            } catch {
                if #available(iOS 14, *) { Logger.replies.debug("Error while loading older replies: \(error)") }
                if let error = error as? ServerCallError, case .serverError(.notAuthenticated) = error {
                    self.error = error.displayableMessage
                }
                olderPages.pageFailed()
                return
            }
            // The page lists nothing above the window when the feed ignored the call, or when its replies were all
            // listed already: the next one may load then.
            DispatchQueue.main.asyncAfter(deadline: .now() + OlderPagesPacing.listingTimeout) { [weak self] in
                guard let self else { return }
                perform(olderPages.timedOut(generation: generation, canLoad: canLoadOlderReplies))
            }
        }
    }

    /// Called as the newest reply of the most recent end enters or leaves the screen: a newer one is followed only
    /// when it was on screen, and the newest replies are polled only while it is.
    func newestReplyOnScreenChanged(_ onScreen: Bool) {
        newestReplyOnScreen = onScreen
        if listsMostRecentEnd {
            shouldFetchLatestReplies.send(onScreen)
        }
    }

    func refresh() async {
        let refreshCommentTask = Task { await refreshComment() }
        let refreshRepliesTask = Task { await refreshFeed() }
        await refreshCommentTask.value
        await refreshRepliesTask.value
    }

    func deleteComment() {
        commentDeletion = .inProgress
        Task {
            await deleteComment()
        }
    }

    func deleteReply(replyId: String) {
        isDeletingReply = true
        Task {
            await deleteReply(replyId: replyId)
            isDeletingReply = false
        }
    }

    func blockAuthor(profileId: String) {
        Task {
            await blockAuthor(profileId: profileId)
        }
    }

    private func startAutoFetchLatestReplies() {
        guard autoFetchLatestRepliesTask == nil else {
            if #available(iOS 14, *) { Logger.replies.trace("startAutoFetchLatestReplies called multiple times") }
            return
        }
        if listsMostRecentEnd, let feed {
            // The window is itself the newest replies: refreshing its newest page and keeping the older ones lists
            // the new ones in one server call, without dropping those the member paged in.
            autoFetchLatestRepliesTask = Task {
                repeat {
                    do {
                        try await feed.refreshNewestItems(
                            pageSize: MostRecentWindow.refreshSize(listedCount: feed.items?.count ?? 0))
                    } catch {
                        if let error = error as? ServerCallError, case .serverError(.notAuthenticated) = error {
                            self.error = error.displayableMessage
                        }
                    }
                    // A page of older replies asked for during the refresh was ignored.
                    loadOlderRepliesIfLoaderVisible()
                    try await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                } while (!Task.isCancelled)
            }
            return
        }
        guard let newestFirstRepliesFeed else { return }

        listenToNewestRepliesFeed()

        let oldestFirstFeed = feed
        autoFetchLatestRepliesTask = Task {
            repeat {
                // only fetch new replies if we are not fetching all replies until the reply to scroll to otherwise
                // it messes up with the scroll. Gated on the load rather than on the reply being reached, so a reply
                // that is never listed (deleted, moderated) does not stop the polling for the screen's life.
                if !scrollTarget.isLoading {
                    do {
                        // The stored replies are listed alone while no page of the server lists the end of the
                        // thread, its first refresh having failed or been ignored: the newest replies polled are not
                        // added to them until then (see `OldestFirstThread.listed`). The thread is refreshed again
                        // first.
                        if let oldestFirstFeed, oldestFirstFeed.endsOnStoredItems {
                            try await oldestFirstFeed.refresh(pageSize: 10)
                            repliesLoadFailure = nil
                        }
                        try await newestFirstRepliesFeed.refresh(pageSize: 10)
                    } catch {
                        if let error = error as? ServerCallError, case .serverError(.notAuthenticated) = error {
                            self.error = error.displayableMessage
                        }
                    }
                }
                // wait for 5 seconds
                try await Task.sleep(nanoseconds: 5 * 1_000_000_000)
            } while (!Task.isCancelled)
        }
    }

    private func loadAllReplies(scrollToBottom: Bool) {
        guard let feed else { return }
        Task {
            defer { hasLoadedReplies = true }
            do {
                try await feed.fetchAll()
                repliesLoadFailure = nil
            } catch {
                if #available(iOS 14, *) { Logger.replies.debug("Error: \(error)") }
                if replies?.isEmpty ?? true { repliesLoadFailure = ScreenStateFailure(error) }
            }
            if scrollToBottom {
                DispatchQueue.main.async {
                    self.hideLoadMoreRepliesLoader = true
                    self.scrollToBottom = true
                }
            }
        }
    }

    private func loadAllReplies(until id: String, in feed: Feed<Reply, Never>) async {
        defer { hasLoadedReplies = true }
        do {
            try await feed.fetchAll(until: id)
            repliesLoadFailure = nil
        } catch {
            if #available(iOS 14, *) { Logger.replies.debug("Error: \(error)") }
            if replies?.isEmpty ?? true { repliesLoadFailure = ScreenStateFailure(error) }
        }
    }

    private func listenToNewestRepliesFeed() {
        guard let newestFirstRepliesFeed else { return }
        autoFetchLatestRepliesCancellable = newestFirstRepliesFeed.$items
            .sink { [unowned self] in
                guard let newestReplies = $0, let feed else { return }
                let newReplyList = merge(oldestFirstRepliesFeedItems: feed.items, of: feed,
                                         newestFirstRepliesFeedItems: newestReplies)
                if newReplyList != modelReplies {
                    modelReplies = newReplyList
                    DispatchQueue.main.async {
                        self.scrollToBottom = true
                    }
                }
            }
    }

    /// The replies listed from the start of the thread, then the newest ones once `feed` reached its end (see
    /// `OldestFirstThread.listed`).
    private func merge(
        oldestFirstRepliesFeedItems: [Reply]?, of feed: Feed<Reply, Never>,
        newestFirstRepliesFeedItems: [Reply])
    -> [Reply]? {
        OldestFirstThread.listed(oldestFirst: oldestFirstRepliesFeedItems, reachedEnd: feed.hasReachedServerEnd,
                                 newestFirst: newestFirstRepliesFeedItems, id: \.uuid)
    }

    private func stopAutoFetchLatestReplies() {
        autoFetchLatestRepliesTask?.cancel()
        autoFetchLatestRepliesTask = nil
        autoFetchLatestRepliesCancellable = nil
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

    private func fetchComment(incrementViewCount: Bool = false) {
        Task {
            do {
                try await fetchComment(uuid: commentUuid, incrementViewCount: incrementViewCount)
                contentLoadFailure = nil
            } catch {
                // Nothing on screen to keep: the failure takes the whole screen, with a retry. A toast
                // over an empty screen would leave a spinner spinning behind it (Screen states spec).
                if comment == nil {
                    contentLoadFailure = ScreenStateFailure(error)
                } else if replies?.isEmpty == false,
                          let error = error as? ServerCallError, case .noNetwork = error {
                    // One error, one channel. Gated on the replies being on screen rather than on
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
        fetchComment()
        refreshFeed()
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
        connectedActionChecker.ensureConnected(action: action, actionWhenNotConnected: authenticationActionBinding)
    }

    private func fetchComment(uuid: String, incrementViewCount: Bool) async throws(ServerCallError) {
        do {
            try await octopus.core.commentsRepository.fetchComment(uuid: commentUuid,
                                                                   incrementViewCount: incrementViewCount)
        } catch {
            if case let .serverError(error) = error, case .notFound = error {
                markCommentNotAvailable()
            } else {
                throw error
            }
        }
    }

    private func markCommentNotAvailable() {
        commentConfirmedNotAvailable = true
        commentNotAvailable = true
    }

    /// Asks the server whether a comment that vanished from the cache still exists: the logout purge also removes
    /// the comments of the previous session, which the next one may still see.
    private func confirmCommentDisappearance() {
        Task {
            await confirmCommentDisappearance()
        }
    }

    private func confirmCommentDisappearance() async {
        let fetchError: ServerCallError?
        do {
            try await octopus.core.commentsRepository.fetchComment(uuid: commentUuid)
            fetchError = nil
        } catch {
            fetchError = error
        }
        switch VanishedContentCheck(fetchError: fetchError) {
        case .stillAvailable:
            // The replies went with the comment.
            await refreshFeed()
        case .gone:
            markCommentNotAvailable()
        case let .unanswered(failure):
            contentLoadFailure = failure
        }
    }

    private func refreshFeed(scrollToTop: Bool = false) {
        Task {
            await refreshFeed(scrollToTop: scrollToTop)
        }
    }

    /// Re-runs the replies' first load after a failure.
    func retryRepliesFirstLoad() {
        repliesLoadFailure = nil
        // Hold the loader until the retry settles, instead of flashing the empty state through the gap.
        hasLoadedReplies = false
        refreshFeed()
    }

    private func refreshNewestReplies() {
        guard let newestFirstRepliesFeed else { return }
        Task {
            do {
                try await newestFirstRepliesFeed.refresh(pageSize: 10)
            } catch {
                if #available(iOS 14, *) {
                    Logger.replies.debug("Error while refreshing the newest replies: \(error)")
                }
            }
        }
    }

    private func refreshComment() async {
        do {
            try await fetchComment(uuid: commentUuid, incrementViewCount: false)
        } catch {
            self.error = error.displayableMessage
        }
    }

    private func refreshFeed(scrollToTop: Bool = false) async {
        guard let feed else { return }
        defer { hasLoadedReplies = true }
        do {
            let pageSize = listsMostRecentEnd
                ? MostRecentWindow.refreshSize(listedCount: feed.items?.count ?? 0)
                : 10
            try await feed.refresh(pageSize: pageSize)
            repliesLoadFailure = nil
        } catch {
            if #available(iOS 14, *) { Logger.replies.debug("Error while refreshing replies feed: \(error)") }
            // No reply listed yet: the failure takes the list's place, with a retry (Screen states spec).
            if replies?.isEmpty ?? true {
                repliesLoadFailure = ScreenStateFailure(error)
            } else if case .serverError(.notAuthenticated) = error {
                self.error = error.displayableMessage
            } else if case .noNetwork = error {
                // Replies are already on screen: a toast says so without replacing them (Screen states spec).
                octopus.core.toastsRepository.display(errorToast: .noNetwork)
            } else {
                octopus.core.toastsRepository.display(errorToast: .unknown)
            }
        }
    }

    private func deleteComment() async {
        do {
            try await octopus.core.commentsRepository.deleteComment(commentId: commentUuid)
            commentDeletion = .done
        } catch {
            commentDeletion = nil
            self.error = error.displayableMessage
        }
    }

    private func deleteReply(replyId: String) async {
        do {
            try await octopus.core.repliesRepository.deleteReply(replyId: replyId)
            replyDeleted = true
        } catch {
            self.error = error.displayableMessage
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
    /// replies at its top came to rest on screen.
    func loadPreviousReplies() {
        guard let feed else { return }
        if listsMostRecentEnd {
            perform(olderPages.loaderRestedOnScreen(canLoad: canLoadOlderReplies))
            return
        }
        Task {
            do {
                try await feed.loadPreviousItems(pageSize: 50)
            } catch {
                if #available(iOS 14, *) { Logger.replies.debug("Error while loading replies feed previous items: \(error)") }
                if let error = error as? ServerCallError, case .serverError(.notAuthenticated) = error {
                   self.error = error.displayableMessage
               }
            }
        }
    }

    func setReaction(_ reaction: ReactionKind?) {
        guard ensureConnected(action: .reaction) else { return }
        guard let comment = internalComment else { return }
        Task {
            await set(reaction: reaction, comment: comment)
        }
    }

    func setReplyReaction(_ reaction: ReactionKind?, replyId: String) {
        guard ensureConnected(action: .reaction) else { return }
        // The listed replies, not the feed's: newer replies merged from the newest-first feed are listed too.
        guard let reply = modelReplies?.first(where: { $0.id == replyId }) else {
            error = .unknownError
            return
        }
        Task {
            await set(reaction: reaction, reply: reply)
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

    private func set(reaction: ReactionKind?, reply: Reply) async {
        do {
            try await octopus.core.repliesRepository.set(
                reaction: reaction, reply: reply,
                parentIsTranslated: translationStore.displayTranslation(for: reply.uuid))
        } catch {
            switch error {
            case let .validation(argumentError):
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
