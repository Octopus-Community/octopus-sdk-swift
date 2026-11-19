//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import Combine
import os
import OctopusDependencyInjection
import OctopusRemoteClient
#if canImport(GRPC)
import GRPC
#else
import GRPCSwift
#endif
import OctopusGrpcModels

extension Injected {
    static let userDataCleanerMonitor = Injector.InjectedIdentifier<UserDataCleanerMonitor>()
}

/// This monitor is in charge of cleaning the database from any user content as soon as the user logs out.
/// It also has what is on screen loaded again when a session appears after there was none or when the community
/// reopens, and the root feeds when a guest becomes a client user.
class UserDataCleanerMonitor: InjectableObject, @unchecked Sendable {
    public static let injectedIdentifier = Injected.userDataCleanerMonitor

    private let userDataStorage: UserDataStorage
    private let context: NSManagedObjectContext
    private let octoObjectsDatabase: OctoObjectsDatabase
    private let notificationsDatabase: NotificationsDatabase
    private let userConfigDatabase: UserConfigDatabase
    private let clientUserProfileMerger: ClientUserProfileMerger
    private let topicsRepository: TopicsRepository
    private let rootFeedsRepository: RootFeedsRepository
    private let sdkEventsEmitter: SdkEventsEmitter

    private var storage: Set<AnyCancellable> = []
    /// Set by `stop()`, not read from `storage`: the closure coordinator starts before this monitor, and a reopening
    /// it sees first still reloads.
    private var isStopped = false

    init(injector: Injector) {
        userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        // The content and notifications databases write through this context, whose queue is serial. The user config
        // lives in another store and is deleted on that store's own context.
        context = injector.getInjected(identifiedBy: Injected.modelCoreDataStack).saveContext
        // Take the postsDatabase as octoObjectsDatabase
        octoObjectsDatabase = injector.getInjected(identifiedBy: Injected.postsDatabase)
        notificationsDatabase = injector.getInjected(identifiedBy: Injected.notificationsDatabase)
        userConfigDatabase = injector.getInjected(identifiedBy: Injected.userConfigDatabase)
        clientUserProfileMerger = injector.getInjected(identifiedBy: Injected.clientUserProfileMerger)
        topicsRepository = injector.getInjected(identifiedBy: Injected.topicsRepository)
        rootFeedsRepository = injector.getInjected(identifiedBy: Injected.rootFeedsRepository)
        sdkEventsEmitter = injector.getInjected(identifiedBy: Injected.sdkEventsEmitter)
    }

    func start() {
        isStopped = false
        // An unreadable session is not a logout: its data is kept until the session can be read again.
        Publishers.CombineLatest(userDataStorage.$userData, userDataStorage.$sessionIsUnreadable)
            .filter { !$1 }
            .map { $0.0 }
            // Who is connected and as what, not their token: a refreshed token is not a new session.
            .removeDuplicates(by: SessionChange.isSameSession)
            .scan(nil) { (change: SessionChange?, userData) in
                SessionChange(previous: change?.current, current: userData, atLaunch: change == nil)
            }
            .compactMap { $0 }
            .sink { [weak self] change in
                guard let self else { return }
                let previous = change.previous, current = change.current
                // A logout, or a client user replaced by another one. A guest who becomes a client user keeps the
                // content: it only has what a guest can see.
                let sessionEnded = current == nil || (previous?.clientId != nil && previous?.id != current?.id)
                if sessionEnded {
                    // At launch without a session, nothing on screen was loaded for one.
                    purge(reload: previous != nil)
                } else if previous == nil && !change.atLaunch {
                    // What loaded while there was no session (after a logout or a community switch, until the
                    // guest or the member is connected) is the anonymous content: a response that comes back
                    // before the session appears is not refused as one sent for another session.
                    reloadContent()
                } else if let previous, previous.clientId == nil, current?.clientId != nil {
                    // The root feeds are fetched for the session, and the guest's are not the member's: their ids name
                    // the guest. Under the same user id too they are fetched again, the server decides whether they
                    // differ. Only they are, so that a sign-in stays cheap: the rest of what is on screen keeps what
                    // was loaded for the guest.
                    fetchRootFeeds()
                }
            }.store(in: &storage)
    }

    func forceClean() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            purge(reload: false) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func stop() {
        isStopped = true
        storage.removeAll()
    }

    /// Has the cached content loaded again once the community reopened: its closure deleted it, and a screen kept
    /// through the closure (pushed under the closure message) would read the deletion as content deleted on the server.
    /// Without a session, nothing is done here: the guest connected at reopening is a session that appears, which
    /// loads it again. Once stopped, nothing is done either: a community switch stops this monitor first, so that
    /// nothing of the community being left loads again.
    func reloadAfterCommunityReopening() {
        guard !isStopped, userDataStorage.userData != nil else { return }
        reloadContent()
    }

    /// Deletes the content cached for the session that ended.
    ///
    /// The deletions are queued before this function returns, on the queue each store writes through: what the
    /// next session writes (the guest reconnection, its access gate, the topics and feeds fetched again) lands after
    /// them instead of being erased by them.
    /// - Parameter reload: whether to ask what is on screen to load again. The UI would otherwise read the deletion
    ///   as content deleted on the server, and the feeds would stay empty.
    private func purge(reload: Bool, completion: @escaping @Sendable (Error?) -> Void = { _ in }) {
        if #available(iOS 14, *) { Logger.profile.trace("Cleaning user based data due to a logout") }
        clientUserProfileMerger.clearLatestClientUser()
        let deletions = DispatchGroup()
        let contentError = FirstError()
        let configError = FirstError()
        deletions.enter()
        context.performQueued({ [context, octoObjectsDatabase, notificationsDatabase] in
            try octoObjectsDatabase.deleteAllOnQueue()
            try notificationsDatabase.deleteAllOnQueue()
            try context.save()
        }, completion: { error in
            contentError.record(error)
            deletions.leave()
        })
        deletions.enter()
        userConfigDatabase.deleteConfigQueued { error in
            configError.record(error)
            deletions.leave()
        }
        deletions.notify(queue: .global()) { [weak self] in
            let error = contentError.value ?? configError.value
            if let error {
                if #available(iOS 14, *) { Logger.profile.debug("Error while cleaning user based data: \(error)") }
            }
            // the content is gone as soon as its own deletion saved: what is on screen loads again even if the
            // config deletion failed, otherwise the feeds stay empty
            if reload && contentError.value == nil {
                self?.reloadContent()
            }
            completion(error)
        }
    }

    /// Same reload as an entitlement change (`EntitlementMonitor`): the feeds on screen and the topics they name, plus
    /// the root feeds, whose ids depend on the session (the anonymous ones name no user).
    private func reloadContent() {
        sdkEventsEmitter.emit(.userContentCleared)
        Task { [topicsRepository] in
            do {
                _ = try await topicsRepository.fetchTopics()
            } catch {
                if #available(iOS 14, *) { Logger.groups.debug("Fetching the topics again failed: \(error)") }
            }
        }
        fetchRootFeeds()
    }

    private func fetchRootFeeds() {
        Task { [rootFeedsRepository] in
            do {
                try await rootFeedsRepository.fetchRootFeeds()
            } catch {
                if #available(iOS 14, *) { Logger.feed.debug("Fetching the root feeds again failed: \(error)") }
            }
        }
    }
}

/// A change of the connected user, as the monitor sees it.
private struct SessionChange {
    let previous: UserDataStorage.UserData?
    let current: UserDataStorage.UserData?
    /// Whether `current` is the session the SDK started with, which is not a change.
    let atLaunch: Bool

    static func isSameSession(_ lhs: UserDataStorage.UserData?, _ rhs: UserDataStorage.UserData?) -> Bool {
        lhs?.id == rhs?.id && lhs?.clientId == rhs?.clientId
    }
}

/// The first error reported by a deletion that completes on another queue.
private final class FirstError: @unchecked Sendable {
    private let lock = NSLock()
    private var error: Error?

    var value: Error? {
        lock.lock()
        defer { lock.unlock() }
        return error
    }

    func record(_ error: Error?) {
        lock.lock()
        defer { lock.unlock() }
        if self.error == nil { self.error = error }
    }
}
