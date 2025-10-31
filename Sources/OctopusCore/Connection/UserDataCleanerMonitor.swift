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

    private let userDataStorage: UserDataStorage
    private let octoObjectsDatabase: OctoObjectsDatabase
    private let notificationsDatabase: NotificationsDatabase
    private let userConfigDatabase: UserConfigDatabase
    private let clientUserProfileMerger: ClientUserProfileMerger

    private var storage: Set<AnyCancellable> = []
    private var magicLinkSubscription: Task<Void, Error>?

    init(injector: Injector) {
        userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        // Take the postsDatabase as octoObjectsDatabase
        octoObjectsDatabase = injector.getInjected(identifiedBy: Injected.postsDatabase)
        notificationsDatabase = injector.getInjected(identifiedBy: Injected.notificationsDatabase)
        userConfigDatabase = injector.getInjected(identifiedBy: Injected.userConfigDatabase)
        clientUserProfileMerger = injector.getInjected(identifiedBy: Injected.clientUserProfileMerger)
    }

    func start() {
        userDataStorage.$userData.removeDuplicates()
            .sink { userData in
                guard userData == nil else { return }
                Task { [self] in
                    if #available(iOS 14, *) { Logger.profile.trace("Cleaning user based data due to a logout") }
                    do {
                        clientUserProfileMerger.clearLatestClientUser()
                        try await octoObjectsDatabase.resetUserInteractions()
                        try await notificationsDatabase.replaceAll(notifications: [])
                        try await userConfigDatabase.deleteConfig()
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
