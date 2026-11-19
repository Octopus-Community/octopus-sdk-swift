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

    /// The migrations being sent, by user id.
    private var migrationsInFlight = [String: Task<StorableCurrentUserProfile, Error>]()
    /// The answers of the migrations that succeeded, by user id. The server does not send a migrated profile as one
    /// still to migrate: such a profile is a copy from before the migration, as the exchange of the client token can
    /// answer with while the fetch of the profile migrates it. Migrated again, a profile without a nickname would get
    /// another one.
    private var migratedProfiles = [String: StorableCurrentUserProfile]()
    /// Number of migrations that got the answer of the one in flight rather than sending their own. Read by the
    /// tests, which keep a migration in flight until another one joins it: such a migration touches nothing else they
    /// can see.
    var joinedMigrationsCount: Int {
        migrationsInFlightLock.lock()
        defer { migrationsInFlightLock.unlock() }
        return _joinedMigrationsCount
    }
    private var _joinedMigrationsCount = 0
    private let migrationsInFlightLock = NSLock()

    init(injector: Injector) {
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        authCallProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)
    }

    func migrateUserToFrictionlessUserIfNeeded(
        profile: Com_Octopuscommunity_PrivateProfile,
        userId: String) async throws(UpdateProfile.Error) -> StorableCurrentUserProfile {
            // profile need migration only if hasConfirmedNickname is null
            guard !profile.hasHasConfirmedNickname_p else {
                return StorableCurrentUserProfile(from: profile, userId: userId)
            }
            // On a launch, the fetch of the profile and the exchange of the client token can both get a profile still
            // to migrate: one migration is sent, whose answer both get. Sent twice, a profile without a nickname
            // would get a different one from each.
            let migration = migrationInFlight(of: profile, userId: userId)
            do {
                return try await migration.value
            } catch let error as UpdateProfile.Error {
                throw error
            } catch {
                throw .serverCall(.other(error))
            }
    }

    /// The migration of `userId`'s profile: the one being sent, or the answer of the one that succeeded, or a new one
    /// started with `profile`.
    private func migrationInFlight(of profile: Com_Octopuscommunity_PrivateProfile, userId: String)
    -> Task<StorableCurrentUserProfile, Error> {
        migrationsInFlightLock.lock()
        defer { migrationsInFlightLock.unlock() }
        if let migratedProfile = migratedProfiles[userId] {
            return Task { migratedProfile }
        }
        if let migrationInFlight = migrationsInFlight[userId] {
            _joinedMigrationsCount += 1
            return migrationInFlight
        }
        let migration = Task { [self] in
            // Removed once it is answered: a profile still to migrate after a failure is migrated again. The lock is
            // held until the migration is registered, so it cannot be removed before.
            do {
                let migratedProfile = try await migrate(profile: profile, userId: userId)
                endMigration(userId: userId, migratedProfile: migratedProfile)
                return migratedProfile
            } catch {
                endMigration(userId: userId, migratedProfile: nil)
                throw error
            }
        }
        migrationsInFlight[userId] = migration
        return migration
    }

    private func endMigration(userId: String, migratedProfile: StorableCurrentUserProfile?) {
        migrationsInFlightLock.lock()
        defer { migrationsInFlightLock.unlock() }
        migrationsInFlight[userId] = nil
        if let migratedProfile {
            migratedProfiles[userId] = migratedProfile
        }
    }

    private func migrate(profile: Com_Octopuscommunity_PrivateProfile, userId: String)
    async throws(UpdateProfile.Error) -> StorableCurrentUserProfile {
            if #available(iOS 14, *) { Logger.profile.debug("Migrating user to a frictionless one.") }
            // if nickname is not present, ask the backend to create one.
            let migratedProfile: UpdateProfileData
            if Self.isMigratedAsConfirmed(profile) {
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
            do {
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
            } catch {
                if let error = error as? UpdateProfile.Error {
                    throw error
                } else if let error = error as? AuthenticatedActionError {
                    throw .serverCall(error)
                } else if let error = error as? RemoteClientError {
                    throw .serverCall(.serverError(ServerError(remoteClientError: error)))
                } else {
                    throw .serverCall(.other(error))
                }
            }
    }

    /// The profile as `migrateUserToFrictionlessUserIfNeeded` would leave it, without asking the server, for when
    /// the migration fails. Stored as it is, an unmigrated profile would read its missing confirmations as
    /// granted, which a profile whose creation was never completed must not.
    ///
    /// The nickname confirmation stays missing, as on the server: that is what tells a profile still to migrate
    /// (see `CurrentUserProfile.isFrictionlessMigrationPending`), which the next exchange of the client token or
    /// fetch of the profile migrates.
    func profileAsMigrated(_ profile: Com_Octopuscommunity_PrivateProfile, userId: String)
    -> StorableCurrentUserProfile {
        guard !profile.hasHasConfirmedNickname_p else {
            return StorableCurrentUserProfile(from: profile, userId: userId)
        }
        let isConfirmed = Self.isMigratedAsConfirmed(profile)
        var migratedProfile = profile
        migratedProfile.hasSeenOnboarding_p = isConfirmed
        migratedProfile.hasAcceptedCgu_p = isConfirmed
        migratedProfile.hasConfirmedBio_p = isConfirmed
        migratedProfile.hasConfirmedPicture_p = isConfirmed
        return StorableCurrentUserProfile(from: migratedProfile, userId: userId)
    }

    /// Whether the migration confirms everything: a profile with a nickname was fully created before frictionless
    /// profiles, one without was never created.
    private static func isMigratedAsConfirmed(_ profile: Com_Octopuscommunity_PrivateProfile) -> Bool {
        profile.nickname.nilIfEmpty != nil
    }
}
