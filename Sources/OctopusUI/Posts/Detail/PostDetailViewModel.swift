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

enum PostDetailNavigationOrigin {
    case clientApp
    case sdk
}

@MainActor
class PostDetailViewModel: ObservableObject {

    struct Post: Equatable {
        enum Attachment: Equatable {
            case image(ImageMedia)
            case video(VideoMedia)
            case poll(DisplayablePoll)
        }
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
        let attachment: Attachment?
        let author: Author
        let relativeDate: String
        let topic: String
        let aggregatedInfo: AggregatedInfo
        let userInteractions: UserInteractions
        let canBeDeleted: Bool
        let canBeModerated: Bool
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
    @Published var scrollToBottom = false
    @Published var scrollToId: String?
    @Published private(set) var hasMoreData = false
    @Published private(set) var hideLoadMoreCommentsLoader = false
    @Published private var modelComments: [Comment]?
    private var autoFetchLatestCommentsTask: Task<Void, Swift.Error>?
    private var autoFetchLatestCommentsCancellable: AnyCancellable?

    @Published var postDeletion: PostDeletion?

    @Published var isDeletingComment = false
    @Published var commentDeleted = false

    @Published var postNotAvailable = false

    var canDisplayClientObject: Bool { octopus.displayClientObjectCallback != nil }

    private var shouldFetchLatestComments = CurrentValueSubject<Bool, Never>(false)
    private var liveMeasures: [String: CurrentValueSubject<LiveMeasures, Never>] = [:]

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
    private let translationStore: ContentTranslationPreferenceStore
    private var newestFirstCommentsFeed: Feed<Comment, Never>?
    private var commentToScrollTo: String?
    private var scrollToMostRecentComment: Bool
    private let origin: PostDetailNavigationOrigin
    private let hasFeaturedComment: Bool

    private var internalPost: OctopusCore.Post?

    private var visibleCommentIds: Set<String> = []
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
         origin: PostDetailNavigationOrigin,
         hasFeaturedComment: Bool) {
        self.octopus = octopus
        self.postUuid = postUuid
        self.commentToScrollTo = commentToScrollTo
        self.scrollToMostRecentComment = scrollToMostRecentComment
        self.origin = origin
        self.hasFeaturedComment = hasFeaturedComment
        self.translationStore = translationStore
        connectedActionChecker = ConnectedActionChecker(octopus: octopus)
        relativeDateFormatterProvider = RelativeDateTimeFormatterProvider(octopus: octopus)

        Publishers.CombineLatest4(
            octopus.core.postsRepository.getPost(uuid: postUuid).removeDuplicates().replaceError(with: nil),
            octopus.core.topicsRepository.$topics.removeDuplicates(),
            octopus.core.profileRepository.profilePublisher.removeDuplicates(),
            octopus.core.configRepository.communityConfigPublisher
                .map { $0?.gamificationConfig?.gamificationLevels }
                .removeDuplicates())
        .sink { [unowned self] post, topics, profile, gamificationLevels in
            self.internalPost = post
            guard postDeletion == nil else { return }
            guard let post else {
                // if post was not nil and is now nil, it means that it has been deleted
                let postWontBeAvailable = self.post != nil
                self.post = nil
                self.comments = nil

                if postWontBeAvailable {
                    postNotAvailable = true
                }
                return
            }

            guard post.canBeDisplayed else {
                self.post = nil
                self.comments = nil
                postNotAvailable = true
                return
            }

            guard let topic = topics.first(where: { $0.uuid == post.parentId }) else {
                self.post = nil
                self.comments = nil
                return
            }
            self.post = Post(from: post,
                             gamificationLevels: gamificationLevels ?? [],
                             thisUserProfileId: profile?.id, topic: topic,
                             dateFormatter: relativeDateFormatterProvider.formatter)
            newestFirstCommentsFeed = post.newestFirstCommentsFeed
            if let oldestFirstCommentsFeed = post.oldestFirstCommentsFeed {
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
                if !hasMoreData && idx == commentsCount - 1 {
                    if #available(iOS 14, *) {
                        Logger.comments.trace("Setting autorefresh actions on \(String(describing: comment.text))")
                    }
                    onAppearAction = { [weak self] in
                        if #available(iOS 14, *) {
                            Logger.comments.trace("Will start autorefresh comments list due to latest comment being displayed")
                        }
                        self?.shouldFetchLatestComments.send(true)
                        self?.queueFetchAdditionalData(id: comment.uuid)
                        self?.visibleCommentIds.insert(comment.uuid)
                    }
                    onDisappearAction = { [weak self] in
                        if #available(iOS 14, *) {
                            Logger.comments.trace("Will stop autorefresh comments list due to latest comment being displayed")
                        }
                        self?.shouldFetchLatestComments.send(false)
                        self?.dequeueFetchAdditionalData(id: comment.uuid)
                        self?.visibleCommentIds.remove(comment.uuid)
                    }
                } else if idx == max(commentsCount - 10, 0), hasMoreData {
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
                        visibleCommentIds.insert(comment.uuid)
                    }
                    onDisappearAction = { [weak self] in
                        self?.dequeueFetchAdditionalData(id: comment.uuid)
                        self?.visibleCommentIds.remove(comment.uuid)
                    }
                } else {
                    onAppearAction = { [weak self] in
                        self?.queueFetchAdditionalData(id: comment.uuid)
                        self?.visibleCommentIds.insert(comment.uuid)
                    }
                    onDisappearAction = { [weak self] in
                        self?.dequeueFetchAdditionalData(id: comment.uuid)
                        self?.visibleCommentIds.remove(comment.uuid)
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
                    thisUserProfileId: profile?.id, dateFormatter: relativeDateFormatterProvider.formatter,
                    onAppearAction: onAppearAction, onDisappearAction: onDisappearAction)
            }
            if newComments.isEmpty {
                shouldFetchLatestComments.send(true)
            } else if !newComments.isEmpty && (self.comments?.isEmpty ?? true) {
                shouldFetchLatestComments.send(false)
            }
            if self.comments != newComments {
                self.comments = newComments
                if let commentToScrollTo = self.commentToScrollTo,
                   self.comments?.contains(where: { $0.uuid == commentToScrollTo }) ?? false {
                    self.scrollToId = "Comment-\(commentToScrollTo)"
                    self.commentToScrollTo = nil
                }
                if #available(iOS 14, *) { Logger.comments.trace("Comments list updated done") }
            }
        }.store(in: &storage)

        fetchPost(incrementViewCount: true)
        fetchTopics()

        octopus.core.commentsRepository.commentSentPublisher
            .sink { [unowned self] comment in
                guard comment.parentId == postUuid else { return }
                // refresh automatically when the comment is created
                hideLoadMoreCommentsLoader = true
                loadAllComments(scrollToBottom: true)
                scrollToBottom = true
            }.store(in: &storage)

        octopus.core.profileRepository.onCurrentUserProfileUpdated.sink { [unowned self] _ in
            fetchPost()
            refreshFeed(isManual: false)
            fetchTopics()
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
                if shouldFetchLatestComments.value {
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
                if shouldFetchLatestComments && UIApplication.shared.applicationState != .background {
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
        stopAutoFetchLatestComments()
    }

    func onAppear() {
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
            error = .localizationKey("Error.Unknown")
            return
        }

        do {
            try callback(clientObjectId)
            octopus.core.trackingRepository.trackClientObjectOpenedFromBridge()
        } catch {
            self.error = .localizationKey("Error.Unknown")
        }
    }

    private func set(feed: Feed<Comment, Never>) {
        guard feed.id != self.feed?.id else { return }
        comments = nil
        self.feed = feed
        feedStorage = []

        feed.$items
            .removeDuplicates()
            .sink { [unowned self] in
                modelComments = merge(oldestFirstCommentsFeedItems: $0 ?? [],
                                      newestFirstCommentsFeedItems: newestFirstCommentsFeed?.items ?? [])
            }.store(in: &feedStorage)

        feed.$hasMoreData
            .removeDuplicates()
            .sink { [unowned self] in
                if #available(iOS 14, *) { Logger.comments.trace("Feed has more data: \($0)") }
                hasMoreData = $0
            }.store(in: &feedStorage)

        Task {
            await feed.populateWithLocalData(pageSize: 10)
        }

        if let commentToScrollTo {
            loadAllComments(until: commentToScrollTo)
        } else if scrollToMostRecentComment {
            loadAllComments(scrollToBottom: true)
            scrollToMostRecentComment = false
        } else {
            refreshFeed(isManual: false)
        }
    }

    func ensureConnected(action: UserAction) -> Bool {
        return connectedActionChecker.ensureConnected(action: action, actionWhenNotConnected: authenticationActionBinding)
    }

    func refresh() async {
        let refreshPostTask = Task { await refreshPost() }
        let refreshTopicsTask = Task { try? await fetchTopics() }
        let refreshCommentsTask = Task { await refreshFeed(isManual: true) }
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
        guard let newestFirstCommentsFeed else { return }

        listenToNewestCommentsFeed()

        autoFetchLatestCommentsTask = Task {
            repeat {
                do {
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
            do {
                try await feed.fetchAll()
            } catch {
                if #available(iOS 14, *) { Logger.comments.debug("Error: \(error)") }
            }
            if scrollToBottom {
                DispatchQueue.main.async {
                    self.hideLoadMoreCommentsLoader = true
                    self.scrollToBottom = true
                }
            }
        }
    }

    private func loadAllComments(until id: String) {
        guard let feed else { return }
        Task {
            do {
                try await feed.fetchAll(until: id)
            } catch {
                if #available(iOS 14, *) { Logger.replies.debug("Error: \(error)") }
            }
        }
    }

    private func listenToNewestCommentsFeed() {
        guard let newestFirstCommentsFeed else { return }
        autoFetchLatestCommentsCancellable = newestFirstCommentsFeed.$items
            .sink { [unowned self] in
                guard let newestComments = $0 else { return }
                let newCommentList = merge(oldestFirstCommentsFeedItems: feed?.items ?? [],
                                           newestFirstCommentsFeedItems: newestComments)
                if newCommentList != modelComments ?? [] {
                    modelComments = newCommentList
                    DispatchQueue.main.async {
                        self.scrollToBottom = true
                    }
                }
            }
    }

    private func merge(
        oldestFirstCommentsFeedItems: [Comment],
        newestFirstCommentsFeedItems: [Comment])
    -> [Comment] {
        var mergedComments = oldestFirstCommentsFeedItems
        for newComment in newestFirstCommentsFeedItems.reversed() {
            if !mergedComments.contains(where: { $0.uuid == newComment.uuid}) {
                mergedComments.append(newComment)
            }
        }
        return mergedComments
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
            try await fetchPost(uuid: postUuid, incrementViewCount: incrementViewCount)
        }
    }

    private func fetchTopics() {
        Task {
            try await fetchTopics()
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

    private func refreshFeed(isManual: Bool, scrollToTop: Bool = false) {
        Task {
            await refreshFeed(isManual: isManual, scrollToTop: scrollToTop)
        }
    }

    private func refreshNewestComments() {
        guard let newestFirstCommentsFeed else { return }
        Task {
            try await newestFirstCommentsFeed.refresh(pageSize: 10)
        }
    }

    private func refreshPost() async {
        do {
            try await fetchPost(uuid: postUuid, incrementViewCount: false)
        } catch {
            self.error = error.displayableMessage
        }
    }

    private func refreshFeed(isManual: Bool, scrollToTop: Bool = false) async {
        guard let feed else { return }
        do {
            try await feed.refresh(pageSize: 10)
        } catch {
            if #available(iOS 14, *) { Logger.comments.debug("Error while refreshing posts feed: \(error)") }
            if isManual {
                self.error = error.displayableMessage
            } else if case .serverError(.notAuthenticated) = error {
                self.error = error.displayableMessage
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

    func loadPreviousComments() {
        guard let feed else { return }
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

    func vote(pollAnswerId: String) -> Bool {
        guard ensureConnected(action: .vote) else { return false }
        guard let post = internalPost else {
            error = .localizationKey("Error.Unknown")
            return false
        }
        Task {
            await vote(pollAnswerId: pollAnswerId, post: post)
        }
        return true
    }

    private func vote(pollAnswerId: String, post: OctopusCore.Post) async {
        do {
            try await octopus.core.postsRepository.vote(
                pollAnswerId: pollAnswerId, post: post,
                parentIsTranslated: translationStore.displayTranslation(for: post.uuid))
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
            }
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
        guard let comment = feed?.items?.first(where: { $0.id == commentId }) else {
            error = .localizationKey("Error.Unknown")
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
            }
        }
    }
}

extension PostDetailViewModel.Post.Attachment {
    init?(from post: Post) {
        if let poll = post.poll {
            self = .poll(DisplayablePoll(from: poll))
        } else if let media = post.medias.first(where: { $0.kind == .video }),
                  let videoMedia = VideoMedia(from: media) {
            self = .video(videoMedia)
        } else if let media = post.medias.first(where: { $0.kind == .image }),
                  let imageMedia = ImageMedia(from: media) {
            self = .image(imageMedia)
        } else {
            return nil
        }
    }
}

extension PostDetailViewModel.Post {
    init(from post: Post,
         gamificationLevels: [GamificationLevel],
         thisUserProfileId: String?, topic: OctopusCore.Topic,
         dateFormatter: RelativeDateTimeFormatter) {
        uuid = post.uuid
        text = post.text
        author = .init(
            profile: post.author,
            gamificationLevel: gamificationLevels.first { $0.level == post.author?.gamificationLevel }
        )
        relativeDate = dateFormatter.localizedString(for: post.creationDate, relativeTo: Date())
        self.topic = topic.name
        attachment = .init(from: post)
        canBeDeleted = post.author != nil && post.author?.uuid == thisUserProfileId
        canBeModerated = post.author?.uuid != thisUserProfileId
        aggregatedInfo = post.aggregatedInfo
        userInteractions = post.userInteractions
        bridgeCTA = if let bridgeInfo = post.clientObjectBridgeInfo,
                       let ctaText = bridgeInfo.ctaText {
            BridgeCTA(text: ctaText, clientObjectId: bridgeInfo.objectId)
        } else {
            nil
        }
        customAction = if let customAction = post.customAction {
            CustomAction(ctaText: customAction.ctaText, targetUrl: customAction.targetUrl)
        } else {
            nil
        }
        catchPhrase = post.clientObjectBridgeInfo?.catchPhrase
    }

    var hasVideo: Bool {
        switch attachment {
        case .video: return true
        default: return false
        }
    }

    var videoId: String? {
        switch attachment {
        case let .video(video): return video.videoId
        default: return nil
        }
    }
}
