//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusDependencyInjection
@testable import OctopusCore

/// A monitor can be released while a task it started is still pending, as when switching community releases the
/// previous core: that task must not reach the released monitor.
///
/// The tasks run on the global executor, so whether one starts before or after its monitor is released is up to the
/// scheduler: many monitors are started and released to make the late start, the one that used to crash, happen.
@Suite(.serialized)
struct MonitorsLifetimeTests {

    /// Deleting a comment makes the monitor start a task that updates the post's child count.
    @Test func aPostChildChangeMonitorReleasedBeforeItsTaskRunsIsLeftAlone() async throws {
        let injector = makeCommentsInjector()
        let commentsRepository = injector.getInjected(identifiedBy: Injected.commentsRepository)
        let commentsDatabase = injector.getInjected(identifiedBy: Injected.commentsDatabase)
        let octoService = try #require(
            injector.getInjected(identifiedBy: Injected.remoteClient).octoService as? MockOctoService)

        var releasedMonitors = [WeakReference]()
        for index in 0..<100 {
            try await commentsDatabase.upsert(comments: [comment(id: "\(index)")])
            octoService.injectNextDeleteCommentResponse(.init())
            let box = MonitorBox()
            box.monitor = PostChildChangeMonitor(injector: injector)
            box.monitor?.start()
            releasedMonitors.append(WeakReference(try #require(box.monitor)))
            // Subscribed after the monitor, so the deletion reaches it right after the monitor on the main queue: the
            // monitor is released before the task its sink just started is likely to run.
            let releaser = commentsRepository.commentDeletedPublisher.sink { _ in box.monitor = nil }

            _ = try await commentsRepository.deleteComment(commentId: "\(index)")
            await MainActor.run { }
            releaser.cancel()
        }

        try await Task.sleep(nanoseconds: .secondsToNano(0.2))
        try await expectWithTimeout(releasedMonitors.allSatisfy { $0.object == nil })
    }

    /// Starting with a language other than the stored one makes the monitor start a task that resets the stored data.
    @Test func aLanguageChangedMonitorReleasedBeforeItsTaskRunsIsLeftAlone() async throws {
        let latestLanguageKey = "OctopusSDK.latestLanguage"
        let storedLanguage = UserDefaults.standard.string(forKey: latestLanguageKey)
        defer { UserDefaults.standard.set(storedLanguage, forKey: latestLanguageKey) }
        let injector = makeLanguageInjector()

        var releasedMonitors = [WeakReference]()
        for _ in 0..<100 {
            UserDefaults.standard.set("previous-language", forKey: latestLanguageKey)
            var monitor: LanguageChangedMonitor? = LanguageChangedMonitor(injector: injector)
            monitor?.start()
            releasedMonitors.append(WeakReference(try #require(monitor)))
            monitor = nil
        }

        try await Task.sleep(nanoseconds: .secondsToNano(0.2))
        try await expectWithTimeout(releasedMonitors.allSatisfy { $0.object == nil })
    }

    private func makeCommentsInjector() -> Injector {
        let injector = Injector()
        injector.register { _ in try! ModelCoreDataStack(inRam: true) }
        injector.register { CommentsDatabase(injector: $0) }
        injector.register { _ in Validators(appManagedFields: []) }
        injector.registerMocks(.remoteClient, .authProvider, .networkMonitor, .appStateMonitor, .blockedUserIdsProvider,
                               .configRepository)
        injector.register { FeedItemInfosDatabase(injector: $0) }
        injector.register { ReplyFeedsStore(injector: $0) }
        injector.register { RepliesDatabase(injector: $0) }
        injector.register { PostsDatabase(injector: $0) }
        injector.register { GamificationRepository(injector: $0) }
        injector.register { ToastsRepository(injector: $0) }
        injector.register { SdkEventsEmitter(injector: $0) }
        injector.register { CommentsRepository(injector: $0) }
        return injector
    }

    private func makeLanguageInjector() -> Injector {
        let injector = Injector()
        injector.register { _ in try! ModelCoreDataStack(inRam: true) }
        injector.registerMocks(.remoteClient, .configRepository)
        injector.register { FeedItemInfosDatabase(injector: $0) }
        injector.register { PostsDatabase(injector: $0) }
        injector.register { LanguageRepository(injector: $0) }
        return injector
    }

    private func comment(id: String) -> StorableComment {
        StorableComment(uuid: id,
                        text: .init(originalText: "Comment", originalLanguage: nil, translatedText: nil),
                        medias: [],
                        author: .init(uuid: "me", nickname: "Me", avatarUrl: nil, gamificationLevel: nil),
                        creationDate: Date(), updateDate: Date(),
                        status: .published, statusReasons: [],
                        parentId: "postId",
                        descReplyFeedId: nil,
                        ascReplyFeedId: nil,
                        aggregatedInfo: .empty,
                        userInteractions: UserInteractions(reaction: nil, pollVoteId: nil))
    }
}

private final class MonitorBox: @unchecked Sendable {
    var monitor: PostChildChangeMonitor?
}

private final class WeakReference {
    weak var object: AnyObject?

    init(_ object: AnyObject) {
        self.object = object
    }
}
