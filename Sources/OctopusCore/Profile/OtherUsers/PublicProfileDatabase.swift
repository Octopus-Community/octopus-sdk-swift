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
    private let gamificationOrder = ProfileGamificationOrder()

    init(injector: Injector) {
        let coreDataStack = injector.getInjected(identifiedBy: Injected.modelCoreDataStack)
        context = coreDataStack.saveContext
    }

    /// Deletes every public profile.
    /// - Warning: To be called on the context's queue, from a block that saves afterwards.
    func deleteAllOnQueue() throws {
        try context.fetch(PublicProfileEntity.fetchAll()).forEach { context.delete($0) }
    }

    func profilePublisher(profileId: String) -> AnyPublisher<StorableProfile?, Never> {
        (context
            .publisher(request: PublicProfileEntity.fetchById(id: profileId)) {
                guard let profileEntity = $0.first else { return [] }
                return [StorableProfile(from: profileEntity)]
            } as AnyPublisher<[StorableProfile], Never>
        )
        .map(\.first)
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }

    /// Stores a public profile read from the server.
    /// - Parameters:
    ///   - profile: the profile.
    ///   - gamificationTicket: taken when the request that read the profile was sent. Its level and total points are
    ///     only written if no newer request has written them since (see `ProfileGamificationOrder`).
    /// - Returns: the profile as cached, whose level and total points are those of that newer request if any.
    @discardableResult
    func upsert(profile: StorableProfile, gamificationTicket: ProfileGamificationOrder.Ticket)
    async throws -> StorableProfile {
        try await context.performAsync { [context, gamificationOrder] in
            let profileEntity: PublicProfileEntity
            let isNewProfile: Bool
            if let existingProfile = try context.fetch(PublicProfileEntity.fetchById(id: profile.id)).first {
                profileEntity = existingProfile
                isNewProfile = false
            } else {
                profileEntity = PublicProfileEntity(context: context)
                profileEntity.profileId = profile.id
                isNewProfile = true
            }

            profileEntity.nickname = profile.nickname
            profileEntity.bio = profile.bio
            profileEntity.pictureUrl = profile.pictureUrl
            profileEntity.defaultAvatar = profile.defaultAvatar
            profileEntity.tagsRawValue = profile.tags.rawValue
            profileEntity.totalMessagesOptional = profile.totalMessages.map { NSNumber(integerLiteral: $0) }
            profileEntity.accountCreationDate = profile.accountCreationDate
            // A new profile takes the response's gamification whatever its ticket, which becomes the one to beat: an
            // older response arriving later is dropped, a newer one is not held back by a ticket from before a purge.
            if gamificationOrder.claim(gamificationTicket, for: profile.id, force: isNewProfile) {
                profileEntity.gamificationLevelOptional = profile.gamificationLevel.map { NSNumber(integerLiteral: $0) }
                profileEntity.gamificationScoreOptional = profile.gamificationScore.map { NSNumber(integerLiteral: $0) }
            }
            profileEntity.descPostFeedId = profile.descPostFeedId
            profileEntity.ascPostFeedId = profile.ascPostFeedId
            profileEntity.descCommentFeedId = profile.descCommentFeedId
            profileEntity.ascCommentFeedId = profile.ascCommentFeedId
            profileEntity.clientUserId = profile.clientUserId

            try context.save()
            return StorableProfile(from: profileEntity)
        }
    }

    /// Writes the connected member's own level and total points on their cached public profile, so the community data
    /// of that member follows the refreshes of their private profile without a fetch of the public one.
    ///
    /// Only a cached profile that already carries a level is updated: the private profile sends its gamification
    /// block even when the community has gamification disabled, so it cannot turn gamification on by itself. A profile
    /// that is not cached is left for its next fetch. Nothing is written either when a request sent after the one of
    /// `gamificationTicket` has already written them (see `ProfileGamificationOrder`), or when they do not change.
    func updateGamificationOfGamifiedProfile(profileId: String, level: Int?, score: Int?,
                                             gamificationTicket: ProfileGamificationOrder.Ticket) async throws {
        try await context.performAsync { [context, gamificationOrder] in
            guard let profileEntity = try context.fetch(PublicProfileEntity.fetchById(id: profileId)).first,
                  profileEntity.gamificationLevelOptional != nil,
                  // Claimed even when the values do not change: an older public profile must not replace them.
                  gamificationOrder.claim(gamificationTicket, for: profileId) else { return }
            let levelValue = level.map { NSNumber(integerLiteral: $0) }
            let scoreValue = score.map { NSNumber(integerLiteral: $0) }
            guard profileEntity.gamificationLevelOptional != levelValue
                    || profileEntity.gamificationScoreOptional != scoreValue else { return }
            profileEntity.gamificationLevelOptional = levelValue
            profileEntity.gamificationScoreOptional = scoreValue
            try context.save()
        }
    }

    func getProfile(profileId: String) async throws -> StorableProfile? {
        try await context.performAsync { [context] in
            try context
                .fetch(PublicProfileEntity.fetchById(id: profileId))
                .first
                .map(StorableProfile.init(from:))
        }
    }
}
