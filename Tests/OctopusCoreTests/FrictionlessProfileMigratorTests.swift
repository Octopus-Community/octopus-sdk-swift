//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusDependencyInjection
import OctopusGrpcModels
@testable import OctopusCore

struct FrictionlessProfileMigratorTests {
    private let migrator: FrictionlessProfileMigrator
    private let userService: MockUserService

    init() {
        let injector = Injector()
        injector.registerMocks(.remoteClient, .authProvider)
        migrator = FrictionlessProfileMigrator(injector: injector)
        userService = injector.getInjected(identifiedBy: Injected.remoteClient).userService as! MockUserService
    }

    /// A profile from before frictionless profiles: without confirmation flags, it has to be migrated.
    private let legacyProfile = Com_Octopuscommunity_PrivateProfile.with {
        $0.id = "profileId"
        $0.nickname = "nickname"
    }

    private let migratedProfileResponse = Com_Octopuscommunity_UpdateProfileResponse.with {
        $0.result = .success(.with {
            $0.profile = .with {
                $0.id = "profileId"
                $0.nickname = "nickname"
                $0.hasSeenOnboarding_p = true
                $0.hasAcceptedCgu_p = true
                $0.hasConfirmedNickname_p = true
                $0.hasConfirmedBio_p = true
                $0.hasConfirmedPicture_p = true
            }
        })
    }

    /// On a launch, the fetch of the profile and the exchange of the client token can both get the profile still to
    /// migrate: one migration is sent, whose answer both get. Sent twice, a profile without a nickname would get a
    /// different one from each.
    @Test func concurrentMigrationsOfAProfileSendOneUpdate() async throws {
        // Two answers, so that a second migration shows in the count rather than as a missing response. The first one
        // is held in flight until the second one joins it: started once the first is answered, the second would get
        // its answer without joining it, and not show whether migrations in flight are shared.
        userService.injectNextUpdateProfileResponse(migratedProfileResponse)
        userService.injectNextUpdateProfileResponse(migratedProfileResponse)
        userService.holdUpdateProfile()
        defer { userService.releaseUpdateProfile() }

        let migrator = migrator
        let profile = legacyProfile
        let first = Task {
            try await migrator.migrateUserToFrictionlessUserIfNeeded(profile: profile, userId: "userId")
        }
        let userService = userService
        try await TaskUtils.wait(for: userService.updateProfileCallCount == 1, timeout: 5)
        let second = Task {
            try await migrator.migrateUserToFrictionlessUserIfNeeded(profile: profile, userId: "userId")
        }
        // sending its own migration instead, it would never join, and the count would show it
        try await TaskUtils.wait(
            for: migrator.joinedMigrationsCount == 1 || userService.updateProfileCallCount == 2, timeout: 5)
        userService.releaseUpdateProfile()
        let firstProfile = try await first.value
        let secondProfile = try await second.value

        #expect(userService.updateProfileCallCount == 1)
        #expect(firstProfile.hasConfirmedNickname == true)
        #expect(secondProfile == firstProfile)
    }

    /// The exchange of the client token can answer with the profile as it was before the migration the fetch of the
    /// profile has just completed. Migrated again, a profile without a nickname would get another one.
    @Test func aProfileAlreadyMigratedIsNotMigratedAgain() async throws {
        userService.injectNextUpdateProfileResponse(migratedProfileResponse)
        // so that a second migration shows in the count rather than as a missing response
        userService.injectNextUpdateProfileResponse(migratedProfileResponse)

        let migratedProfile = try await migrator.migrateUserToFrictionlessUserIfNeeded(
            profile: legacyProfile, userId: "userId")
        let profile = try await migrator.migrateUserToFrictionlessUserIfNeeded(
            profile: legacyProfile, userId: "userId")

        #expect(userService.updateProfileCallCount == 1)
        #expect(profile == migratedProfile)
    }

    /// Once a migration is over, a profile still to migrate is migrated again: the previous one may have failed.
    @Test func aMigrationAfterAnotherOneIsSent() async throws {
        userService.injectNextUpdateProfileError(.timeout)
        userService.injectNextUpdateProfileResponse(migratedProfileResponse)

        await #expect(throws: UpdateProfile.Error.self) {
            try await migrator.migrateUserToFrictionlessUserIfNeeded(profile: legacyProfile, userId: "userId")
        }
        let profile = try await migrator.migrateUserToFrictionlessUserIfNeeded(profile: legacyProfile, userId: "userId")

        #expect(userService.updateProfileCallCount == 2)
        #expect(profile.hasConfirmedNickname == true)
    }
}
