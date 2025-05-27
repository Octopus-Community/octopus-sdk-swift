//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import os
import OctopusDependencyInjection
import OctopusRemoteClient
import GRPC
import OctopusGrpcModels

extension Injected {
    static let userDataCleanerMonitor = Injector.InjectedIdentifier<UserDataCleanerMonitor>()
}

/// This monitor is in charge of cleaning the database from any user content as soon as the user logs out.
class UserDataCleanerMonitor: InjectableObject, @unchecked Sendable {
    public static let injectedIdentifier = Injected.userDataCleanerMonitor

    private let injector: Injector
    private let userDataStorage: UserDataStorage
    private let postsDatabase: PostsDatabase
    private let commentsDatabase: CommentsDatabase
    private let repliesDatabase: RepliesDatabase
    private let notificationsDatabase: NotificationsDatabase

    private var storage: Set<AnyCancellable> = []
    private var magicLinkSubscription: Task<Void, Error>?

    init(injector: Injector) {
        self.injector = injector
        userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        postsDatabase = injector.getInjected(identifiedBy: Injected.postsDatabase)
        commentsDatabase = injector.getInjected(identifiedBy: Injected.commentsDatabase)
        repliesDatabase = injector.getInjected(identifiedBy: Injected.repliesDatabase)
        notificationsDatabase = injector.getInjected(identifiedBy: Injected.notificationsDatabase)
    }

    func start() {
        userDataStorage.$userData.removeDuplicates()
            .sink { userData in
                guard userData == nil else { return }
                Task { [self] in
                    if #available(iOS 14, *) { Logger.profile.trace("Cleaning user based data due to a logout") }
                    do {
                        try await postsDatabase.resetUserInteractions()
                        try await commentsDatabase.resetUserInteractions()
                        try await repliesDatabase.resetUserInteractions()
                        try await notificationsDatabase.replaceAll(notifications: [])
                    } catch {
                        if #available(iOS 14, *) { Logger.profile.debug("Error while cleaning user based data: \(error)") }
                    }
                }
            }.store(in: &storage)
    }

    func stop() {
        storage.removeAll()
    }
}
