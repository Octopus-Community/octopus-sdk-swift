//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import SwiftUI
import os
import Octopus
import OctopusCore

@MainActor
class PostFeedViewModel: ObservableObject {

    @Published private(set) var posts: [DisplayablePost]?
    @Published private(set) var hasMoreData = true
    @Published private(set) var error: DisplayableString?
    @Published private(set) var isDeletingContent = false
    @Published var contentDeleted = false

    var thisUserProfileId: String? {
        octopus.core.profileRepository.profile?.id
    }

    let octopus: OctopusSDK
    let feed: Feed<Post, Comment>
    private let translationStore: ContentTranslationPreferenceStore
    private var storage = [AnyCancellable]()

    private var visiblePostIds: Set<String> = []
    private var additionalDataToFetch: CurrentValueSubject<Set<String>, Never> = .init([])
    private var liveMeasures: [String: CurrentValueSubject<LiveMeasures, Never>] = [:]

    let ensureConnected: (UserAction) -> Bool

    var canDisplayClientObject: Bool { octopus.displayClientObjectCallback != nil }

    private var relativeDateFormatter: RelativeDateTimeFormatter = {
        let relativeDateFormatter = RelativeDateTimeFormatter()
        relativeDateFormatter.dateTimeStyle = .numeric
        relativeDateFormatter.unitsStyle = .short

        return relativeDateFormatter
    }()

    init(octopus: OctopusSDK, postFeed: Feed<Post, Comment>, displayModeratedPosts: Bool = false,
         translationStore: ContentTranslationPreferenceStore,
         ensureConnected: @escaping (UserAction) -> Bool) {
        self.octopus = octopus
        self.feed = postFeed
        self.translationStore = translationStore
        self.ensureConnected = ensureConnected
        if #available(iOS 14, *) { Logger.posts.trace("Display post feed \(postFeed.id) \(Date())") }

        loadRemoteTopics()

        /// Reload all posts when app moves to foreground
        NotificationCenter.default
            .publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [unowned self] _ in
                refreshFeed(isManual: false)
                loadRemoteTopics()
            }
            .store(in: &storage)

        octopus.core.profileRepository.onCurrentUserProfileUpdated.sink { [unowned self] _ in
            refreshFeed(isManual: false)
            loadRemoteTopics()
        }.store(in: &storage)

        octopus.core.postsRepository.postDeletedPublisher.sink { [unowned self] in
            refreshFeed(isManual: false)
            loadRemoteTopics()
        }.store(in: &storage)

        octopus.core.postsRepository.postSentPublisher.sink { [unowned self] in
            refreshFeed(isManual: false)
            loadRemoteTopics()
        }.store(in: &storage)

        Publishers.CombineLatest3(
            feed.$items.removeDuplicates(),
            octopus.core.topicsRepository.$topics,
            octopus.core.profileRepository.profilePublisher.removeDuplicates()
        )
        .sink { [unowned self] posts, topics, profile in
            guard let posts else { return }
            let postCount = posts.count
            let newPosts = posts.enumerated().compactMap { idx, post -> DisplayablePost? in
                guard post.canBeDisplayed || displayModeratedPosts else { return nil }
                guard let topic = topics.first(where: { $0.uuid == post.parentId }) else { return nil }
                let onAppear: () -> Void
                if idx == max(postCount - 10, 0), feed.hasMoreData {
                    onAppear = { [weak self] in
                        if #available(iOS 14, *) { Logger.posts.trace("Will refresh post list due to trigger") }
                        self?.loadPreviousItems()
                        self?.queueFetchAdditionalData(id: post.uuid)
                        self?.visiblePostIds.insert(post.uuid)
                        if let featuredCommentUuid = post.featuredComment?.uuid {
                            self?.queueFetchAdditionalData(id: featuredCommentUuid)
                            self?.visiblePostIds.insert(featuredCommentUuid)
                        }
                    }
                } else {
                    onAppear = { [weak self] in
                        self?.queueFetchAdditionalData(id: post.uuid)
                        self?.visiblePostIds.insert(post.uuid)
                        if let featuredCommentUuid = post.featuredComment?.uuid {
                            self?.queueFetchAdditionalData(id: featuredCommentUuid)
                            self?.visiblePostIds.insert(featuredCommentUuid)
                        }
                    }
                }

                let onDisappear: () -> Void = { [weak self] in
                    self?.dequeueFetchAdditionalData(id: post.uuid)
                    self?.visiblePostIds.remove(post.uuid)
                    if let featuredCommentUuid = post.featuredComment?.uuid {
                        self?.queueFetchAdditionalData(id: featuredCommentUuid)
                        self?.visiblePostIds.insert(featuredCommentUuid)
                    }
                }

                let liveMeasuresPublisher = getOrCreateLiveMeasuresPublisher(contentId: post.uuid)
                liveMeasuresPublisher.send(LiveMeasures(aggregatedInfo: post.aggregatedInfo,
                                                        userInteractions: post.userInteractions))

                let childLiveMeasuresPublisher: CurrentValueSubject<LiveMeasures, Never>?
                if let featuredComment = post.featuredComment {
                    childLiveMeasuresPublisher = getOrCreateLiveMeasuresPublisher(contentId: featuredComment.uuid)
                    childLiveMeasuresPublisher!.send(LiveMeasures(aggregatedInfo: featuredComment.aggregatedInfo,
                                                            userInteractions: featuredComment.userInteractions))
                } else {
                    childLiveMeasuresPublisher = nil
                }


                return DisplayablePost(from: post, liveMeasuresPublisher: liveMeasuresPublisher,
                                       childLiveMeasuresPublisher: childLiveMeasuresPublisher,
                                       thisUserProfileId: profile?.id, topic: topic,
                                       dateFormatter: relativeDateFormatter,
                                       onAppear: onAppear, onDisappear: onDisappear)
            }
            if self.posts != newPosts {
                self.posts = newPosts
                if #available(iOS 14, *) { Logger.posts.trace("Posts list updated done") }
            }
        }.store(in: &storage)

        feed.$hasMoreData
            .removeDuplicates()
            .sink { [unowned self] in
                hasMoreData = $0
            }.store(in: &storage)

        additionalDataToFetch
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .sink { [unowned self] in
                guard !$0.isEmpty else { return }
                let additionalDataToFetch = Array(additionalDataToFetch.value)
                Task {
                    do {
                        try await octopus.core.postsRepository.fetchAdditionalData(ids: additionalDataToFetch,
                                                                                   incrementViewCount: true)
                    } catch {
                        if let error = error as? ServerCallError, case .serverError(.notAuthenticated) = error {
                            self.error = error.displayableMessage
                        }
                    }
                }
                self.additionalDataToFetch.send([])
            }
            .store(in: &storage)

        Task {
            await feed.populateWithLocalData(pageSize: 10)
        }

        refreshFeed(isManual: false)
    }

    func refresh() async {
        if #available(iOS 14, *) { Logger.posts.trace("Refresh async called") }
        // refresh topics and remote posts
        await withTaskGroup(of: Void.self) { group in
            let topicsRepository = octopus.core.topicsRepository
            let postsRepository = octopus.core.postsRepository
            group.addTask { try? await topicsRepository.fetchTopics() }
            group.addTask { [self] in await refreshFeed(isManual: true) }
            group.addTask { [self] in
                try? await postsRepository.fetchAdditionalData(ids: Array(visiblePostIds),
                                                               incrementViewCount: false)
            }

            await group.waitForAll()
        }
    }

    func deletePost(postId: String) {
        isDeletingContent = true
        Task {
            await deletePost(postId: postId)
            isDeletingContent = false
        }
    }

    func deleteComment(commentId: String) {
        isDeletingContent = true
        Task {
            await deleteComment(commentId: commentId)
            isDeletingContent = false
        }
    }

    func setReaction(_ reaction: ReactionKind?, postId: String) {
        guard ensureConnected(.reaction) else { return }
        guard let post = feed.items?.first(where: { $0.id == postId }) else {
            error = .localizationKey("Error.Unknown")
            return
        }
        Task {
            await set(reaction: reaction, post: post)
        }
    }

    func setCommentReaction(_ reaction: ReactionKind?, commentId: String) {
        guard ensureConnected(.reaction) else { return }
        let comment = feed.items?.first(where: { $0.featuredComment?.uuid == commentId })?.featuredComment
        guard let comment else {
            error = .localizationKey("Error.Unknown")
            return
        }
        Task {
            await set(reaction: reaction, comment: comment)
        }
    }

    func vote(pollAnswerId: String, postId: String) -> Bool {
        guard ensureConnected(.vote) else { return false }
        guard let post = feed.items?.first(where: { $0.id == postId }) else {
            error = .localizationKey("Error.Unknown")
            return false
        }
        Task {
            await vote(pollAnswerId: pollAnswerId, post: post)
        }
        return true
    }

    func displayClientObject(clientObjectId: String) {
        guard let callback = octopus.displayClientObjectCallback else {
            error = .localizationKey("Error.Unknown")
            return
        }

        do {
            try callback(clientObjectId)
            Task {
                try? await octopus.core.trackingRepository.trackClientObjectOpenedFromBridge()
            }
        } catch {
            self.error = .localizationKey("Error.Unknown")
        }
    }

    private func set(reaction: ReactionKind?, post: Post) async {
        do {
            try await octopus.core.postsRepository.set(reaction: reaction, post: post, parentIsTranslated: translationStore.displayTranslation(for: post.uuid))
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

    private func vote(pollAnswerId: String, post: Post) async {
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

    private func deletePost(postId: String) async {
        do {
            try await octopus.core.postsRepository.deletePost(postId: postId)
            contentDeleted = true
        } catch {
            self.error = error.displayableMessage
        }
    }

    private func deleteComment(commentId: String) async {
        do {
            try await octopus.core.commentsRepository.deleteComment(commentId: commentId)
            contentDeleted = true
        } catch {
            self.error = error.displayableMessage
        }
    }

    func refreshFeed(isManual: Bool) {
        if #available(iOS 14, *) { Logger.posts.trace("Refresh feed") }
        Task {
            await refreshFeed(isManual: isManual)
        }
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

    private func refreshFeed(isManual: Bool) async {
        do {
            try await feed.refresh(pageSize: 10)
        } catch {
            if #available(iOS 14, *) { Logger.posts.debug("Error while refreshing posts feed: \(error)") }
            if isManual {
                self.error = error.displayableMessage
            } else if case .serverError(.notAuthenticated) = error {
                self.error = error.displayableMessage
            }
        }
    }

    func loadPreviousItems() {
        Task {
            do {
                try await feed.loadPreviousItems(pageSize: 50)
            } catch {
                if #available(iOS 14, *) { Logger.posts.debug("Error while loading posts feed previous items: \(error)") }
            }
        }
    }

    private func loadRemoteTopics() {
        Task { [octopus] in
            try await octopus.core.topicsRepository.fetchTopics()
        }
    }

    private func getOrCreateLiveMeasuresPublisher(contentId: String) -> CurrentValueSubject<LiveMeasures, Never> {
        if let existingPublisher = liveMeasures[contentId] {
            return existingPublisher
        } else {
            let newPublisher = CurrentValueSubject<LiveMeasures, Never>(
                LiveMeasures(aggregatedInfo: .empty, userInteractions: .empty))
            liveMeasures[contentId] = newPublisher
            return newPublisher
        }
    }
}
