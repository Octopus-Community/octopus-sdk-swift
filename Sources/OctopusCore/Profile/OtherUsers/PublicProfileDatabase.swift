//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import Combine
import OctopusDependencyInjection

extension Injected {
    static let publicProfileDatabase = Injector.InjectedIdentifier<PublicProfileDatabase>()
}

class PublicProfileDatabase: InjectableObject {
    static let injectedIdentifier = Injected.publicProfileDatabase

    private let coreDataStack: CoreDataStack
    private let context: NSManagedObjectContext

    init(injector: Injector) {
        coreDataStack = injector.getInjected(identifiedBy: Injected.coreDataStack)
        context = coreDataStack.saveContext
    }

    func profilePublisher(profileId: String) -> AnyPublisher<StorableProfile?, Error> {
        return context
            .publisher(request: PublicProfileEntity.fetchById(id: profileId)) {
                guard let profileEntity = $0.first else { return [] }
                return [StorableProfile(from: profileEntity)]
            }
            .map(\.first)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func upsert(profile: StorableProfile) async throws {
        try await context.performAsync { [context] in
            let profileEntity: PublicProfileEntity
            if let existingProfile = try context.fetch(PublicProfileEntity.fetchById(id: profile.id)).first {
                profileEntity = existingProfile
            } else {
                profileEntity = PublicProfileEntity(context: context)
                profileEntity.profileId = profile.id
            }

            profileEntity.nickname = profile.nickname
            profileEntity.bio = profile.bio
            profileEntity.pictureUrl = profile.pictureUrl
            profileEntity.descPostFeedId = profile.descPostFeedId
            profileEntity.ascPostFeedId = profile.ascPostFeedId

            try context.save()
        }
    }
}
