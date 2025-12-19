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

    private let context: NSManagedObjectContext

    init(injector: Injector) {
        let coreDataStack = injector.getInjected(identifiedBy: Injected.modelCoreDataStack)
        context = coreDataStack.saveContext
    }

    func profilePublisher(profileId: String) -> AnyPublisher<StorableProfile?, Error> {
        (context
            .publisher(request: PublicProfileEntity.fetchById(id: profileId)) {
                guard let profileEntity = $0.first else { return [] }
                return [StorableProfile(from: profileEntity)]
            } as AnyPublisher<[StorableProfile], Error>
        )
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
            profileEntity.tagsRawValue = profile.tags.rawValue
            profileEntity.totalMessagesOptional = profile.totalMessages.map { NSNumber(integerLiteral: $0) }
            profileEntity.accountCreationDate = profile.accountCreationDate
            profileEntity.gamificationLevelOptional = profile.gamificationLevel.map { NSNumber(integerLiteral: $0) }
            profileEntity.descPostFeedId = profile.descPostFeedId
            profileEntity.ascPostFeedId = profile.ascPostFeedId

            try context.save()
        }
    }
}
