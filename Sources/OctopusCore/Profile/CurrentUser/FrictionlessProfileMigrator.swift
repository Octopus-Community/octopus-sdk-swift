//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import OctopusRemoteClient
import os
import OctopusDependencyInjection
import OctopusGrpcModels

extension Injected {
    static let frictionlessProfileMigrator = Injector.InjectedIdentifier<FrictionlessProfileMigrator>()
}

class FrictionlessProfileMigrator: InjectableObject, @unchecked Sendable {
    static let injectedIdentifier = Injected.frictionlessProfileMigrator

    private let remoteClient: OctopusRemoteClient
    private let authCallProvider: AuthenticatedCallProvider

    init(injector: Injector) {
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        authCallProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)
    }

    func migrateUserToFrictionlessUserIfNeeded(
        profile: Com_Octopuscommunity_PrivateProfile,
        userId: String) async throws -> StorableCurrentUserProfile {
            // profile need migration only if hasConfirmedNickname is null
            guard !profile.hasHasConfirmedNickname_p else {
                return StorableCurrentUserProfile(from: profile, userId: userId)
            }
            if #available(iOS 14, *) { Logger.profile.debug("Migrating user to a frictionless one.") }
            // if nickname is not present, ask the backend to create one.
            let migratedProfile: UpdateProfileData
            if profile.nickname.nilIfEmpty != nil {
                // This is the case of a fully created profile but comming from a non-frictionless env
                migratedProfile = .init(
                    hasSeenOnboarding: .updated(true),
                    hasAcceptedCgu: .updated(true),
                    hasConfirmedNickname: .updated(true),
                    hasConfirmedBio: .updated(true),
                    hasConfirmedPicture: .updated(true)
                )
            } else {
                // This is the case where the user was logged in before migration but has never passed the profile
                // creation step.
                migratedProfile = .init(
                    hasSeenOnboarding: .updated(false),
                    hasAcceptedCgu: .updated(false),
                    hasConfirmedNickname: .updated(false),
                    hasConfirmedBio: .updated(false),
                    hasConfirmedPicture: .updated(false),
                    optFindAvailableNickname: true
                )
            }
            let response = try await remoteClient.userService.updateProfile(
                userId: userId,
                profile: migratedProfile,
                authenticationMethod: try authCallProvider.authenticatedMethod())
            switch response.result {
            case let .success(content):
                return StorableCurrentUserProfile(from: content.profile, userId: userId)
            case let .fail(failure):
                throw UpdateProfile.Error.validation(.init(from: failure))
            case .none:
                throw UpdateProfile.Error.serverCall(.other(nil))
            }
    }
}
