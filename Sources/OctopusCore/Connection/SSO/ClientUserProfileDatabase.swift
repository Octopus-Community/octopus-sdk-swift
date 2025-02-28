//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import Combine
import DependencyInjection

extension Injected {
    static let clientUserProfileDatabase = Injector.InjectedIdentifier<ClientUserProfileDatabase>()
}

class ClientUserProfileDatabase: InjectableObject {
    static let injectedIdentifier = Injected.clientUserProfileDatabase

    private let coreDataStack: CoreDataStack
    private let context: NSManagedObjectContext

    init(injector: Injector) {
        coreDataStack = injector.getInjected(identifiedBy: Injected.coreDataStack)
        context = coreDataStack.saveContext
    }

    func profilePublisher(clientUserId: String) -> AnyPublisher<ClientUserProfile?, Error> {
        return context
            .publisher(request: ClientUserEntity.fetchByClientUserId(clientUserId)) {
                guard let profileEntity = $0.first?.profile else { return [] }
                return [ClientUserProfile(from: profileEntity)]
            }
            .map(\.first)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func upsert(profile: ClientUserProfile, clientUserId: String) async throws {
        try await context.performAsync { [context] in
            let clientUserEntity: ClientUserEntity
            if let existingClientUser = try context.fetch(ClientUserEntity.fetchByClientUserId(clientUserId)).first {
                clientUserEntity = existingClientUser
            } else {
                clientUserEntity = ClientUserEntity(context: context)
                clientUserEntity.clientUserId = clientUserId
            }

            let profileEntity = ClientUserProfileEntity(context: context)
            profileEntity.nickname = profile.nickname
            profileEntity.bio = profile.bio
            profileEntity.picture = profile.picture
            profileEntity.ageInformationValue = profile.ageInformation.entity.rawValue
            clientUserEntity.profile = profileEntity

            try context.save()
        }
    }

    func delete(clientUserId: String) async throws {
        try await context.performAsync { [context] in
            guard let existingEntity = try context.fetch(ClientUserEntity.fetchByClientUserId(clientUserId)).first else { return }
            context.delete(existingEntity)
            try context.save()
        }
    }
}
