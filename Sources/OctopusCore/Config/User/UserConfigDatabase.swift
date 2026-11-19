//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import CoreData
import Combine
import OctopusDependencyInjection
import OctopusGrpcModels

extension Injected {
    static let userConfigDatabase = Injector.InjectedIdentifier<UserConfigDatabase>()
}

/// A read of the access found the session it was sent with over: no access, nothing stored, the session is to be
/// replaced (`UserConfigDatabase.endedSessionPublisher`).
struct SessionEndedError: Error {}

extension ServerCallError {
    /// Whether the read of the access failed because the server says the session is over.
    var isSessionEnded: Bool {
        if case let .other(error) = self { return error is SessionEndedError }
        return false
    }
}

class UserConfigDatabase: InjectableObject {
    static let injectedIdentifier = Injected.userConfigDatabase

    private let context: NSManagedObjectContext
    private let endedSessionSubject = PassthroughSubject<UserDataStorage.UserData?, Never>()

    /// The sessions a read of the access found over, as they were when the read was sent: the one of the guest a
    /// banned device was given, once the account behind it is no longer banned. Published from the task of the read.
    var endedSessionPublisher: AnyPublisher<UserDataStorage.UserData?, Never> {
        endedSessionSubject.eraseToAnyPublisher()
    }

    init(injector: Injector) {
        let coreDataStack = injector.getInjected(identifiedBy: Injected.configCoreDataStack)
        context = coreDataStack.saveContext
    }

    func configPublisher() -> AnyPublisher<UserConfig?, Never> {
        (context
            .publisher(request: UserConfigEntity.fetch()) {
                guard let configEntity = $0.first, let config = UserConfig(from: configEntity) else { return [] }
                return [config]
            } as AnyPublisher<[UserConfig], Never>
        )
        .map(\.first)
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }

    /// Stores the access a read gave, unless the server says the session the read was sent with is over: that is no
    /// access to show, and the stored one stays until the session that replaces it reads its own. That session is
    /// published on `endedSessionPublisher` instead.
    /// - Parameter session: the session the read was sent with.
    /// - Returns: the access stored, `nil` when the session is over.
    @discardableResult
    func store(accessRead response: Com_Octopuscommunity_CanAccessCommunityResponse,
               session: UserDataStorage.UserData?) async throws -> UserConfig? {
        if !response.canAccessCommunity, case .sessionEnded? = response.noAccessReason {
            endedSessionSubject.send(session)
            return nil
        }
        let userConfig = UserConfig(from: response)
        try await upsert(userConfig)
        return userConfig
    }

    func upsert(canAccessCommunity: Bool, message: String?) async throws {
        try await upsert(UserConfig(canAccessCommunity: canAccessCommunity, accessDeniedMessage: message))
    }

    func upsert(_ config: UserConfig) async throws {
        try await context.performAsync { [context] in
            let configEntity: UserConfigEntity
            if let existingConfig = try context.fetch(UserConfigEntity.fetch()).first {
                configEntity = existingConfig
            } else {
                configEntity = UserConfigEntity(context: context)
            }
            configEntity.fill(with: config)

            try context.save()
        }
    }

    /// Deletes the stored config and saves, on this database's own context. The deletion is queued before this
    /// function returns (see `performQueued`): an `upsert` requested afterwards, such as the next session's access
    /// gate, runs after it instead of being erased by it.
    func deleteConfigQueued(completion: @escaping @Sendable (Error?) -> Void) {
        context.performQueued({ [context] in
            guard let existingConfig = try context.fetch(UserConfigEntity.fetch()).first else { return }
            context.delete(existingConfig)
            try context.save()
        }, completion: completion)
    }
}
