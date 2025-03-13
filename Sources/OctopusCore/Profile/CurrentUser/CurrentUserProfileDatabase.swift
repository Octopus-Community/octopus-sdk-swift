//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import Combine
import os
import DependencyInjection

extension Injected {
    static let currentUserProfileDatabase = Injector.InjectedIdentifier<CurrentUserProfileDatabase>()
}

class CurrentUserProfileDatabase: InjectableObject {
    static let injectedIdentifier = Injected.currentUserProfileDatabase

    private let coreDataStack: CoreDataStack
    private let context: NSManagedObjectContext

    init(injector: Injector) {
        coreDataStack = injector.getInjected(identifiedBy: Injected.coreDataStack)
        context = coreDataStack.saveContext
    }

    func profilePublisher(userId: String) -> AnyPublisher<StorableCurrentUserProfile?, Error> {
        return context
            .publisher(request: PrivateProfileEntity.fetchByUserId(userId: userId)) {
                guard let profileEntity = $0.first else { return [] }
                return [StorableCurrentUserProfile(from: profileEntity)]
            }
            .map(\.first)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func upsert(profile: StorableCurrentUserProfile) async throws {
        try await context.performAsync { [context] in
            let profileEntity: PrivateProfileEntity
            if let existingProfile = try context.fetch(PrivateProfileEntity.fetchById(id: profile.id)).first {
                profileEntity = existingProfile
            } else {
                profileEntity = PrivateProfileEntity(context: context)
                profileEntity.profileId = profile.id
                profileEntity.userId = profile.userId
            }

            profileEntity.nickname = profile.nickname
            profileEntity.email = profile.email
            profileEntity.bio = profile.bio
            profileEntity.pictureUrl = profile.pictureUrl
            profileEntity.blocking = NSOrderedSet(array: profile.blockedProfileIds.map {
                let blockUserEntity = BlockedUserEntity(context: context)
                blockUserEntity.profileId = $0
                return blockUserEntity
            })
            profileEntity.descPostFeedId = profile.descPostFeedId
            profileEntity.ascPostFeedId = profile.ascPostFeedId

            try context.save()
        }
    }

    func update(blockedProfileIds: [String], on profileId: String) async throws {
        try await context.performAsync { [context] in
            guard let existingProfile = try context.fetch(PrivateProfileEntity.fetchById(id:profileId)).first else {
                if #available(iOS 14, *) { Logger.profile.debug("Dev error: updating blockedProfileIds without existing profile") }
                return
            }
            existingProfile.blocking = NSOrderedSet(array: blockedProfileIds.map {
                let blockUserEntity = BlockedUserEntity(context: context)
                blockUserEntity.profileId = $0
                return blockUserEntity
            })

            try context.save()
        }
    }

    func delete(profileId: String) async throws {
        try await context.performAsync { [context] in
            guard let existingProfile = try context.fetch(PrivateProfileEntity.fetchById(id: profileId)).first else { return }
            context.delete(existingProfile)
            try context.save()
        }
    }
}
