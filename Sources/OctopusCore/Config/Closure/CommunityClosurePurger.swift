//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import os
import OctopusDependencyInjection

extension Injected {
    static let communityClosurePurger = Injector.InjectedIdentifier<CommunityClosurePurger>()
}

/// Empties what the SDK cached once the community is closed, so that nothing of it is shown or published to the host
/// app (groups, related posts, community data, unseen notifications) while it is.
protocol CommunityClosurePurger: Sendable {
    func purge() async throws
}

/// Deletes the content, the notifications and the pending analytics events, and sets the unseen notifications count
/// to 0.
///
/// Unlike the purge of a logout, it keeps the session and the current user profile: the identity of a guest is only
/// its session, which must still be theirs when the community reopens, and without its profile the SDK would take the
/// user for disconnected. It reloads nothing either: no call may leave while the community is closed.
final class CommunityClosurePurgerDefault: CommunityClosurePurger, InjectableObject, @unchecked Sendable {
    static let injectedIdentifier = Injected.communityClosurePurger

    private let context: NSManagedObjectContext
    private let octoObjectsDatabase: OctoObjectsDatabase
    private let notificationsDatabase: NotificationsDatabase
    private let rootFeedsDatabase: RootFeedsDatabase
    private let feedItemInfosDatabase: FeedItemInfosDatabase
    private let publicProfileDatabase: PublicProfileDatabase
    private let currentUserProfileDatabase: CurrentUserProfileDatabase
    private let eventsDatabase: EventsDatabase

    init(injector: Injector) {
        // Every database below but the events one writes through this context.
        context = injector.getInjected(identifiedBy: Injected.modelCoreDataStack).saveContext
        // Take the postsDatabase as octoObjectsDatabase: it deletes every content, topics included.
        octoObjectsDatabase = injector.getInjected(identifiedBy: Injected.postsDatabase)
        notificationsDatabase = injector.getInjected(identifiedBy: Injected.notificationsDatabase)
        rootFeedsDatabase = injector.getInjected(identifiedBy: Injected.rootFeedsDatabase)
        feedItemInfosDatabase = injector.getInjected(identifiedBy: Injected.feedItemInfosDatabase)
        publicProfileDatabase = injector.getInjected(identifiedBy: Injected.publicProfileDatabase)
        currentUserProfileDatabase = injector.getInjected(identifiedBy: Injected.currentUserProfileDatabase)
        eventsDatabase = injector.getInjected(identifiedBy: Injected.eventsDatabase)
    }

    func purge() async throws {
        if #available(iOS 14, *) { Logger.config.trace("Purging the cached data of the closed community") }
        try await context.performAsync { [self] in
            try octoObjectsDatabase.deleteAllOnQueue()
            try notificationsDatabase.deleteAllOnQueue()
            try rootFeedsDatabase.deleteAllOnQueue()
            try feedItemInfosDatabase.deleteAllOnQueue()
            try publicProfileDatabase.deleteAllOnQueue()
            try currentUserProfileDatabase.resetNotificationBadgeCountsOnQueue()
            try context.save()
        }
        let pendingEventIds = try await eventsDatabase.getAllEvents().map(\.uuid)
        try await eventsDatabase.deleteAll(ids: pendingEventIds)
        try OctopusFileStorageProvider.clearCachedFolder()
    }
}
