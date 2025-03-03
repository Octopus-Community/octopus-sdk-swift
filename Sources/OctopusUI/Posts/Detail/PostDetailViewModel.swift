//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus
import OctopusCore
import UIKit

@MainActor
class PostDetailViewModel: ObservableObject {

    struct Post: Equatable {
        let uuid: String
        let headline: String
        let text: String?
        let image: ImageMedia?
        let author: Author
        let relativeDate: String
        let topic: String
        let aggregatedInfo: AggregatedInfo
        let userInteractions: UserInteractions
        let canBeDeleted: Bool
        let canBeModerated: Bool
    }

    struct Comment: Equatable {
        let uuid: String
        let text: String?
        let image: ImageMedia?
        let author: Author
        let relativeDate: String
        let canBeDeleted: Bool
        let canBeModerated: Bool

        let aggregatedInfo: AggregatedInfo
        let userInteractions: UserInteractions
        let liveMeasures: AnyPublisher<LiveMeasures, Never>

        let displayEvents: CellDisplayEvents

        static func == (lhs: PostDetailViewModel.Comment, rhs: PostDetailViewModel.Comment) -> Bool {
            return lhs.uuid == rhs.uuid &&
            lhs.text == rhs.text &&
            lhs.image == rhs.image &&
            lhs.author == rhs.author &&
            lhs.relativeDate == rhs.relativeDate &&
            lhs.canBeDeleted == rhs.canBeDeleted &&
            lhs.canBeModerated == rhs.canBeModerated
        }
    }

    enum PostDeletion {
        case inProgress
        case done
    }

    @Published private(set) var post: Post?
    @Published private(set) var error: DisplayableString?

    // Comments
    private var feedStorage = [AnyCancellable]()
    private var feed: Feed<OctopusCore.Comment>?

    @Published private(set) var comments: [Comment]?
    @Published var scrollToBottom = false
    @Published private(set) var hasMoreData = false
    @Published private(set) var hideLoadMoreCommentsLoader = false
    @Published private var modelComments: [OctopusCore.Comment]?
    private var autoFetchLatestCommentsTask: Task<Void, Swift.Error>?
    private var autoFetchLatestCommentsCancellable: AnyCancellable?

    @Published var openLogin = false
    @Published var openCreateProfile = false
    @Published var openUserProfile = false

    @Published var postDeletion: PostDeletion?

    @Published var isDeletingComment = false
    @Published var commentDeleted = false

    @Published var postNotAvailable = false

    @Published private(set) var ssoError: DisplayableString? // TODO: Delete when router is fully used

    private var shouldFetchLatestComments = CurrentValueSubject<Bool, Never>(false)
    private var liveMeasures: [String: CurrentValueSubject<LiveMeasures, Never>] = [:]

    var thisUserProfileId: String? {
        octopus.core.profileRepository.profile?.id
    }

    let octopus: OctopusSDK
    let postUuid: String
    private var newestFirstCommentsFeed: Feed<OctopusCore.Comment>?
    private var scrollToMostRecentComment: Bool

    private var internalPost: OctopusCore.Post?

    private var visibleCommentIds: Set<String> = []
    private var additionalDataToFetch: CurrentValueSubject<Set<String>, Never> = .init([])

    private var storage = [AnyCancellable]()

    private var relativeDateFormatter: RelativeDateTimeFormatter = {
        let relativeDateFormatter = RelativeDateTimeFormatter()
        relativeDateFormatter.dateTimeStyle = .numeric
        relativeDateFormatter.unitsStyle = .short

        return relativeDateFormatter
    }()

    init(octopus: OctopusSDK, postUuid: String, scrollToMostRecentComment: Bool) {
        self.octopus = octopus
        self.postUuid = postUuid
        self.scrollToMostRecentComment = scrollToMostRecentComment

        Publishers.CombineLatest3(
            octopus.core.postsRepository.getPost(uuid: postUuid).removeDuplicates().replaceError(with: nil),
            octopus.core.topicsRepository.$topics.removeDuplicates(),
            octopus.core.profileRepository.$profile.removeDuplicates())
        .sink { [unowned self] post, topics, profile in
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
            self.post = Post(from: post, thisUserProfileId: profile?.id, topic: topic,
                             dateFormatter: relativeDateFormatter)
            newestFirstCommentsFeed = post.newestFirstCommentsFeed
            if let oldestFirstCommentsFeed = post.oldestFirstCommentsFeed {
                set(feed: oldestFirstCommentsFeed)
            }

        }.store(in: &storage)

        Publishers.CombineLatest(
            $modelComments.removeDuplicates(),
            octopus.core.profileRepository.$profile.removeDuplicates()
        )
        .sink { [unowned self] comments, profile in
            guard let comments else {
                self.comments = nil
                return
            }
            let commentsCount = comments.count
            let newComments = comments.enumerated().compactMap { [unowned self] idx, comment -> Comment? in
                guard comment.canBeDisplayed else { return nil }
                let onAppearAction: () -> Void
                let onDisappearAction: () -> Void
                if !hasMoreData && idx == commentsCount - 1 {
                    print("Setting autorefresh actions on \(String(describing: comment.text))")
                    onAppearAction = { [weak self] in
                        print("Will start autorefresh comments list due to latest comment being displayed")
                        self?.shouldFetchLatestComments.send(true)
                        self?.queueFetchAdditionalData(id: comment.uuid)
                        self?.visibleCommentIds.insert(comment.uuid)
                    }
                    onDisappearAction = { [weak self] in
                        print("Will stop autorefresh comments list due to latest comment being displayed")
                        self?.shouldFetchLatestComments.send(false)
                        self?.dequeueFetchAdditionalData(id: comment.uuid)
                        self?.visibleCommentIds.remove(comment.uuid)
                    }
                } else if idx == max(commentsCount - 10, 0), hasMoreData {
                    print("Setting refresh actions on \(String(describing: comment.text))")
                    onAppearAction = { [weak self] in
                        guard let self else { return }
                        if !hideLoadMoreCommentsLoader {
                            print("Will refresh comments list due to trigger")
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
                return Comment(from: comment, liveMeasurePublisher: liveMeasurePublisher.eraseToAnyPublisher(),
                               thisUserProfileId: profile?.id, dateFormatter: relativeDateFormatter,
                               onAppearAction: onAppearAction, onDisappearAction: onDisappearAction)
            }
            if newComments.isEmpty {
                shouldFetchLatestComments.send(true)
            } else if !newComments.isEmpty && (self.comments?.isEmpty ?? true) {
                shouldFetchLatestComments.send(false)
            }
            if self.comments != newComments {
                self.comments = newComments
                print("Comments list updated done")
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

        $openUserProfile
            .removeDuplicates()
            .dropFirst()
            .sink { [unowned self] in
                // refresh automatically when the user profile is dismissed
                guard !$0 else { return }
                fetchPost()
                fetchTopics()
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
    }

    private func set(feed: Feed<OctopusCore.Comment>) {
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
                print("Feed has more data: \($0)")
                hasMoreData = $0
            }.store(in: &feedStorage)

        Task {
            await feed.populateWithLocalData(pageSize: 10)
        }

        if scrollToMostRecentComment {
            loadAllComments(scrollToBottom: true)
            scrollToMostRecentComment = false
        } else {
            refreshFeed(isManual: false)
        }
    }

    func userProfileTapped() {
        switch octopus.core.connectionRepository.connectionState {
        case .notConnected, .magicLinkSent:
            if case let .sso(config) = octopus.core.connectionRepository.connectionMode {
                config.loginRequired()
            } else {
                openLogin = true
            }
        case let .clientConnected(_, error):
            switch error {
            case let .detailedErrors(errors):
                if let error = errors.first(where: { $0.reason == .userBanned }) {
                    ssoError = .localizedString(error.message)
                } else {
                    fallthrough
                }
            default:
                ssoError = .localizationKey("Connection.SSO.Error.Unknown")
            }
        case .profileCreationRequired:
            openCreateProfile = true
        case .connected:
            openUserProfile = true
        }
    }

    func createCommentTappedWithoutBeeingLoggedIn() {
        switch octopus.core.connectionRepository.connectionState {
        case .notConnected, .magicLinkSent:
            if case let .sso(config) = octopus.core.connectionRepository.connectionMode {
                config.loginRequired()
            } else {
                openLogin = true
            }
        case let .clientConnected(_, error):
            switch error {
            case let .detailedErrors(errors):
                if let error = errors.first(where: { $0.reason == .userBanned }) {
                    ssoError = .localizedString(error.message)
                } else {
                    fallthrough
                }
            default:
                ssoError = .localizationKey("Connection.SSO.Error.Unknown")
            }
        case .profileCreationRequired:
            openCreateProfile = true
        case .connected:
            break
        }
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
            print("startAutoFetchLatestComments called multiple times")
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
                print("Error: \(error)")
            }
            if scrollToBottom {
                DispatchQueue.main.async {
                    self.hideLoadMoreCommentsLoader = true
                    self.scrollToBottom = true
                }
            }
        }
    }

    private func listenToNewestCommentsFeed() {
        guard let newestFirstCommentsFeed else { return }
        autoFetchLatestCommentsCancellable = newestFirstCommentsFeed.$items
            .sink { [unowned self] in
                guard let newestComments = $0 else { return }
                let newCommentList = merge(oldestFirstCommentsFeedItems: modelComments ?? [],
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
        oldestFirstCommentsFeedItems: [OctopusCore.Comment],
        newestFirstCommentsFeedItems: [OctopusCore.Comment])
    -> [OctopusCore.Comment] {
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

    func ensureConnected() -> Bool {
        switch octopus.core.connectionRepository.connectionState {
        case .notConnected, .magicLinkSent:
            if case let .sso(config) = octopus.core.connectionRepository.connectionMode {
                config.loginRequired()
            } else {
                openLogin = true
            }
        case let .clientConnected(_, error):
            switch error {
            case let .detailedErrors(errors):
                if let error = errors.first(where: { $0.reason == .userBanned }) {
                    ssoError = .localizedString(error.message)
                } else {
                    fallthrough
                }
            default:
                ssoError = .localizationKey("Connection.SSO.Error.Unknown")
            }
        case .profileCreationRequired:
            openCreateProfile = true
        case .connected:
            return true
        }
        return false
    }

    // TODO: Delete when router is fully used
    func linkClientUserToOctopusUser() {
        Task {
            await linkClientUserToOctopusUser()
        }
    }

    // TODO: Delete when router is fully used
    private func linkClientUserToOctopusUser() async {
        do {
            try await octopus.core.connectionRepository.linkClientUserToOctopusUser()
        } catch {
            switch error {
            case let .detailedErrors(errors):
                if let error = errors.first(where: { $0.reason == .userBanned }) {
                    ssoError = .localizedString(error.message)
                } else {
                    fallthrough
                }
            default:
                ssoError = .localizationKey("Connection.SSO.Error.Unknown")
            }
        }
    }

    private func fetchTopics() {
        Task {
            try await fetchTopics()
        }
    }

    private func fetchPost(uuid: String, incrementViewCount: Bool) async throws(ServerCallError) {
        do {
            try await octopus.core.postsRepository.fetchPost(uuid: postUuid, incrementViewCount: incrementViewCount)
        } catch {
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
            print("Error while refreshing posts feed: \(error)")
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
                print("Error while loading posts feed previous items: \(error)")
                if let error = error as? ServerCallError, case .serverError(.notAuthenticated) = error {
                   self.error = error.displayableMessage
               }
            }
        }
    }

    func togglePostLike() {
        guard ensureConnected() else { return }
        guard let post = internalPost else { return }
        Task {
            await togglePostLike(post: post)
        }
    }

    func toggleCommentLike(commentId: String) {
        guard ensureConnected() else { return }
        let comment = feed?.items?.first(where: { $0.id == commentId }) ??
            newestFirstCommentsFeed?.items?.first(where: { $0.id == commentId })
        guard let comment else {
            error = .localizationKey("Error.Unknown")
            return
        }
        Task {
            await toggleCommentLike(comment: comment)
        }
    }

    private func togglePostLike(post: OctopusCore.Post) async {
        do {
            try await octopus.core.postsRepository.toggleLike(post: post)
        } catch {
            switch error {
            case let .validation(argumentError):
                // special case where the error missingParent is returned: reload the post to check that it has not been
                // deleted
                for error in argumentError.errors.values.flatMap({ $0 }) {
                    if case .missingParent = error.detail {
                        try? await octopus.core.postsRepository.fetchPost(uuid: post.uuid)
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

    private func toggleCommentLike(comment: OctopusCore.Comment) async {
        do {
            try await octopus.core.commentsRepository.toggleLike(comment: comment)
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

extension PostDetailViewModel.Post {
    init(from post: Post, thisUserProfileId: String?, topic: Topic, dateFormatter: RelativeDateTimeFormatter) {
        uuid = post.uuid
        headline = post.headline
        text = post.text
        author = .init(profile: post.author)
        relativeDate = dateFormatter.localizedString(for: post.creationDate, relativeTo: Date())
        self.topic = topic.name
        image = ImageMedia(from: post.medias.first(where: { $0.kind == .image }))
        canBeDeleted = post.author != nil && post.author?.uuid == thisUserProfileId
        canBeModerated = post.author?.uuid != thisUserProfileId
        aggregatedInfo = post.aggregatedInfo
        userInteractions = post.userInteractions
    }
}

extension PostDetailViewModel.Comment {
    init(from comment: Comment, liveMeasurePublisher: AnyPublisher<LiveMeasures, Never>,
         thisUserProfileId: String?, dateFormatter: RelativeDateTimeFormatter,
         onAppearAction: @escaping () -> Void, onDisappearAction: @escaping () -> Void) {
        uuid = comment.uuid
        text = comment.text
        author = .init(profile: comment.author)
        relativeDate = dateFormatter.customLocalizedStructure(for: comment.creationDate, relativeTo: Date())
        image = ImageMedia(from: comment.medias.first(where: { $0.kind == .image }))
        canBeDeleted = comment.author != nil && comment.author?.uuid == thisUserProfileId
        canBeModerated = comment.author?.uuid != thisUserProfileId
        aggregatedInfo = .empty//comment.aggregatedInfo
        userInteractions = .empty//comment.userInteractions
        liveMeasures = liveMeasurePublisher
        displayEvents = CellDisplayEvents(onAppear: onAppearAction, onDisappear: onDisappearAction)
    }
}
