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
        let text: String?
        let image: ImageMedia?
        let author: Author
        let relativeDate: String
        let aggregatedInfo: AggregatedInfo
        let userInteractions: UserInteractions
        let canBeDeleted: Bool
        let canBeModerated: Bool
    }

    enum CommentDeletion {
        case inProgress
        case done
    }

    @Published private(set) var comment: CommentDetail?
    @Published private(set) var error: DisplayableString?

    // Comments
    private var feedStorage = [AnyCancellable]()
    private var feed: Feed<Reply>?

    @Published private(set) var replies: [DisplayableFeedResponse]?
    @Published var scrollToBottom = false
    @Published var scrollToId: String?
    @Published private(set) var hasMoreData = false
    @Published private(set) var hideLoadMoreRepliesLoader = false
    @Published private var modelReplies: [Reply]?
    private var autoFetchLatestRepliesTask: Task<Void, Swift.Error>?
    private var autoFetchLatestRepliesCancellable: AnyCancellable?

    @Published var commentDeletion: CommentDeletion?

    @Published var isDeletingReply = false
    @Published var replyDeleted = false

    @Published var commentNotAvailable = false

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
    private var newestFirstRepliesFeed: Feed<Reply>?
    private var reply: Bool
    private var replyToScrollTo: String?

    private var internalComment: Comment?

    private var visibleReplyIds: Set<String> = []
    private var additionalDataToFetch: CurrentValueSubject<Set<String>, Never> = .init([])

    private var storage = [AnyCancellable]()

    private var relativeDateFormatter: RelativeDateTimeFormatter = {
        let relativeDateFormatter = RelativeDateTimeFormatter()
        relativeDateFormatter.dateTimeStyle = .numeric
        relativeDateFormatter.unitsStyle = .short

        return relativeDateFormatter
    }()

    init(octopus: OctopusSDK, commentUuid: String, reply: Bool, replyToScrollTo: String?) {
        self.octopus = octopus
        self.commentUuid = commentUuid
        self.reply = reply
        self.replyToScrollTo = replyToScrollTo
        connectedActionChecker = ConnectedActionChecker(octopus: octopus)

        Publishers.CombineLatest(
            octopus.core.commentsRepository.getComment(uuid: commentUuid).removeDuplicates().replaceError(with: nil),
            octopus.core.profileRepository.$profile.removeDuplicates())
        .sink { [unowned self] comment, profile in
            self.internalComment = comment
            guard commentDeletion == nil else { return }
            guard let comment else {
                // if comment was not nil and is now nil, it means that it has been deleted
                let commentWontBeAvailable = self.comment != nil
                self.comment = nil
                self.replies = nil

                if commentWontBeAvailable {
                    commentNotAvailable = true
                }
                return
            }

            guard comment.canBeDisplayed else {
                self.comment = nil
                self.replies = nil
                commentNotAvailable = true
                return
            }

            self.comment = CommentDetail(from: comment, thisUserProfileId: profile?.id,
                                         dateFormatter: relativeDateFormatter)
            newestFirstRepliesFeed = comment.newestFirstRepliesFeed
            if let oldestFirstRepliesFeed = comment.oldestFirstRepliesFeed {
                set(feed: oldestFirstRepliesFeed)
            }

        }.store(in: &storage)

        Publishers.CombineLatest(
            $modelReplies.removeDuplicates(),
            octopus.core.profileRepository.$profile.removeDuplicates()
        )
        .sink { [unowned self] reply, profile in
            guard let reply else {
                self.replies = nil
                return
            }
            let repliesCount = reply.count
            let newReplies = reply.enumerated().compactMap { [unowned self] idx, reply -> DisplayableFeedResponse? in
                guard reply.canBeDisplayed else { return nil }
                let onAppearAction: () -> Void
                let onDisappearAction: () -> Void
                if !hasMoreData && idx == repliesCount - 1 {
                    if #available(iOS 14, *) {
                        Logger.replies.trace("Setting autorefresh actions on \(String(describing: reply.text))")
                    }
                    onAppearAction = { [weak self] in
                        if #available(iOS 14, *) {
                            Logger.replies.trace("Will start autorefresh replies list due to latest reply being displayed")
                        }
                        self?.shouldFetchLatestReplies.send(true)
                        self?.queueFetchAdditionalData(id: reply.uuid)
                        self?.visibleReplyIds.insert(reply.uuid)
                    }
                    onDisappearAction = { [weak self] in
                        if #available(iOS 14, *) {
                            Logger.replies.trace("Will stop autorefresh replies list due to latest reply being displayed")
                        }
                        self?.shouldFetchLatestReplies.send(false)
                        self?.dequeueFetchAdditionalData(id: reply.uuid)
                        self?.visibleReplyIds.remove(reply.uuid)
                    }
                } else if idx == max(repliesCount - 10, 0), hasMoreData {
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
                        visibleReplyIds.insert(reply.uuid)
                    }
                    onDisappearAction = { [weak self] in
                        self?.dequeueFetchAdditionalData(id: reply.uuid)
                        self?.visibleReplyIds.remove(reply.uuid)
                    }
                } else {
                    onAppearAction = { [weak self] in
                        self?.queueFetchAdditionalData(id: reply.uuid)
                        self?.visibleReplyIds.insert(reply.uuid)
                    }
                    onDisappearAction = { [weak self] in
                        self?.dequeueFetchAdditionalData(id: reply.uuid)
                        self?.visibleReplyIds.remove(reply.uuid)
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
                    liveMeasurePublisher: liveMeasurePublisher.eraseToAnyPublisher(),
                    thisUserProfileId: profile?.id, dateFormatter: relativeDateFormatter,
                    onAppearAction: onAppearAction, onDisappearAction: onDisappearAction)
            }
            if newReplies.isEmpty {
                shouldFetchLatestReplies.send(true)
            } else if !newReplies.isEmpty && (self.replies?.isEmpty ?? true) {
                shouldFetchLatestReplies.send(false)
            }
            if self.replies != newReplies {
                self.replies = newReplies
                if let replyToScrollTo = self.replyToScrollTo,
                   replies?.contains(where: { $0.uuid == replyToScrollTo }) ?? false {
                    self.scrollToId = "Reply-\(replyToScrollTo)"
                    self.replyToScrollTo = nil
                }
                if #available(iOS 14, *) { Logger.comments.trace("Replies list updated done") }
            }
        }.store(in: &storage)

        fetchComment(incrementViewCount: true)

        octopus.core.repliesRepository.replySentPublisher
            .sink { [unowned self] reply in
                guard reply.parentId == commentUuid else { return }
                // refresh automatically when the reply is created
                hideLoadMoreRepliesLoader = true
                loadAllReplies(scrollToBottom: true)
                scrollToBottom = true
            }.store(in: &storage)

        octopus.core.profileRepository.onCurrentUserProfileUpdated.sink { [unowned self] _ in
            fetchComment()
            refreshFeed(isManual: false)
        }.store(in: &storage)

        /// Reload comment when app moves to foreground
        NotificationCenter.default
            .publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [unowned self] _ in
                fetchComment(incrementViewCount: true)
                if shouldFetchLatestReplies.value {
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
                if shouldFetchLatestReplies && UIApplication.shared.applicationState != .background {
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
        stopAutoFetchLatestReplies()
    }

    func onAppear() {
        if shouldFetchLatestReplies.value {
            startAutoFetchLatestReplies()
        }
    }

    private func set(feed: Feed<Reply>) {
        guard feed.id != self.feed?.id else { return }
        replies = nil
        self.feed = feed
        feedStorage = []

        feed.$items
            .removeDuplicates()
            .sink { [unowned self] in
                modelReplies = merge(oldestFirstRepliesFeedItems: $0 ?? [],
                                     newestFirstRepliesFeedItems: newestFirstRepliesFeed?.items ?? [])
            }.store(in: &feedStorage)

        feed.$hasMoreData
            .removeDuplicates()
            .sink { [unowned self] in
                if #available(iOS 14, *) { Logger.replies.trace("Feed has more data: \($0)") }
                hasMoreData = $0
            }.store(in: &feedStorage)

        Task {
            await feed.populateWithLocalData(pageSize: 10)
        }

        if let replyToScrollTo {
            loadAllReplies(until: replyToScrollTo)
        } else if reply {
            loadAllReplies(scrollToBottom: true)
            reply = false
        } else {
            refreshFeed(isManual: false)
        }
    }

    func refresh() async {
        let refreshCommentTask = Task { await refreshComment() }
        let refreshRepliesTask = Task { await refreshFeed(isManual: true) }
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

    private func startAutoFetchLatestReplies() {
        guard autoFetchLatestRepliesTask == nil else {
            if #available(iOS 14, *) { Logger.replies.trace("startAutoFetchLatestReplies called multiple times") }
            return
        }
        guard let newestFirstRepliesFeed else { return }

        listenToNewestRepliesFeed()

        autoFetchLatestRepliesTask = Task {
            repeat {
                // only fetch new replies if we are not fetching all replies until the replyToScrollTo otherwise it
                // messes up with the scroll
                if replyToScrollTo == nil {
                    do {
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
            do {
                try await feed.fetchAll()
            } catch {
                if #available(iOS 14, *) { Logger.replies.debug("Error: \(error)") }
            }
            if scrollToBottom {
                DispatchQueue.main.async {
                    self.hideLoadMoreRepliesLoader = true
                    self.scrollToBottom = true
                }
            }
        }
    }

    private func loadAllReplies(until id: String) {
        guard let feed else { return }
        Task {
            do {
                try await feed.fetchAll(until: id)
            } catch {
                if #available(iOS 14, *) { Logger.replies.debug("Error: \(error)") }
            }
        }
    }

    private func listenToNewestRepliesFeed() {
        guard let newestFirstRepliesFeed else { return }
        autoFetchLatestRepliesCancellable = newestFirstRepliesFeed.$items
            .sink { [unowned self] in
                guard let newestReplies = $0 else { return }
                let newReplyList = merge(oldestFirstRepliesFeedItems: feed?.items ?? [],
                                         newestFirstRepliesFeedItems: newestReplies)
                if newReplyList != modelReplies ?? [] {
                    modelReplies = newReplyList
                    DispatchQueue.main.async {
                        self.scrollToBottom = true
                    }
                }
            }
    }

    private func merge(
        oldestFirstRepliesFeedItems: [Reply],
        newestFirstRepliesFeedItems: [Reply])
    -> [Reply] {
        var mergedReplies = oldestFirstRepliesFeedItems
        for newReply in newestFirstRepliesFeedItems.reversed() {
            if !mergedReplies.contains(where: { $0.uuid == newReply.uuid}) {
                mergedReplies.append(newReply)
            }
        }
        return mergedReplies
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
            try await fetchComment(uuid: commentUuid, incrementViewCount: incrementViewCount)
        }
    }

    func ensureConnected() -> Bool {
        connectedActionChecker.ensureConnected(actionWhenNotConnected: authenticationActionBinding)
    }

    private func fetchComment(uuid: String, incrementViewCount: Bool) async throws(ServerCallError) {
        do {
            try await octopus.core.commentsRepository.fetchComment(uuid: commentUuid,
                                                                   incrementViewCount: incrementViewCount)
        } catch {
            if case let .serverError(error) = error, case .notFound = error {
                commentNotAvailable = true
            } else {
                throw error
            }
        }
    }

    private func refreshFeed(isManual: Bool, scrollToTop: Bool = false) {
        Task {
            await refreshFeed(isManual: isManual, scrollToTop: scrollToTop)
        }
    }

    private func refreshNewestReplies() {
        guard let newestFirstRepliesFeed else { return }
        Task {
            try await newestFirstRepliesFeed.refresh(pageSize: 10)
        }
    }

    private func refreshComment() async {
        do {
            try await fetchComment(uuid: commentUuid, incrementViewCount: false)
        } catch {
            self.error = error.displayableMessage
        }
    }

    private func refreshFeed(isManual: Bool, scrollToTop: Bool = false) async {
        guard let feed else { return }
        do {
            try await feed.refresh(pageSize: 10)
        } catch {
            if #available(iOS 14, *) { Logger.replies.debug("Error while refreshing replies feed: \(error)") }
            if isManual {
                self.error = error.displayableMessage
            } else if case .serverError(.notAuthenticated) = error {
                self.error = error.displayableMessage
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

    func loadPreviousReplies() {
        guard let feed else { return }
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

    func toggleCommentLike() {
        guard ensureConnected() else { return }
        guard let comment = internalComment else { return }
        Task {
            await toggleCommentLike(comment: comment)
        }
    }

    func toggleReplyLike(replyId: String) {
        guard ensureConnected() else { return }
        let reply = feed?.items?.first(where: { $0.id == replyId }) ??
            newestFirstRepliesFeed?.items?.first(where: { $0.id == replyId })
        guard let reply else {
            error = .localizationKey("Error.Unknown")
            return
        }
        Task {
            await toggleReplyLike(reply: reply)
        }
    }

    private func toggleCommentLike(comment: Comment) async {
        do {
            try await octopus.core.commentsRepository.toggleLike(comment: comment)
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
            }
        }
    }

    private func toggleReplyLike(reply: Reply) async {
        do {
            try await octopus.core.repliesRepository.toggleLike(reply: reply)
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
            }
        }
    }
}

extension CommentDetailViewModel.CommentDetail {
    init(from comment: Comment, thisUserProfileId: String?, dateFormatter: RelativeDateTimeFormatter) {
        uuid = comment.uuid
        text = comment.text
        image = ImageMedia(from: comment.medias.first(where: { $0.kind == .image }))
        author = .init(profile: comment.author)
        relativeDate = dateFormatter.localizedString(for: comment.creationDate, relativeTo: Date())
        canBeDeleted = comment.author != nil && comment.author?.uuid == thisUserProfileId
        canBeModerated = comment.author?.uuid != thisUserProfileId
        aggregatedInfo = comment.aggregatedInfo
        userInteractions = comment.userInteractions
    }
}
