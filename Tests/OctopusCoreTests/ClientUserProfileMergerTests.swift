//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusDependencyInjection
import OctopusRemoteClient
@testable import OctopusCore

/// Merges of the host's profile when the app manages the nickname.
struct ClientUserProfileMergerTests {
    private let merger: ClientUserProfileMerger
    private let userService: MockUserService

    init() {
        let injector = Injector()
        injector.registerMocks(.remoteClient, .authProvider, .networkMonitor, .configRepository, .appStateMonitor)
        injector.register { ToastsRepository(injector: $0) }
        injector.register { SdkEventsEmitter(injector: $0) }
        injector.register { GamificationRepository(injector: $0) }
        merger = ClientUserProfileMerger(appManagedFields: [.nickname], injector: injector)
        userService = injector.getInjected(identifiedBy: Injected.remoteClient).userService as! MockUserService
    }

    /// The host asked for a nickname that was taken, so the server gave a variant of it, not yet confirmed.
    /// The bio is not confirmed either, so the host's bio is synced.
    private let profileWithVariant = StorableCurrentUserProfile.create(
        id: "profileId", userId: "userId", nickname: "clientNickname1", originalNickname: "clientNickname",
        bio: "clientBio", hasConfirmedNickname: false, hasConfirmedBio: false)

    @Test func theCurrentVariantAloneSendsNothing() async throws {
        let clientUser = ClientUser(
            userId: "clientUserId",
            profile: .init(nickname: "clientNickname1", bio: "clientBio", picture: nil))

        let updatedProfile = try await merger.updateProfileWithClientUser(
            clientUser, profile: profileWithVariant, userId: "userId")

        #expect(updatedProfile == nil)
        #expect(userService.lastUpdateProfileData == nil)
    }

    @Test func theCurrentVariantIsConfirmedAlongWithAnotherChange() async throws {
        userService.injectNextUpdateProfileResponse(.with {
            $0.result = .success(.with {
                $0.profile = .with {
                    $0.id = "profileId"
                    $0.nickname = "clientNickname1"
                    $0.bio = "newClientBio"
                }
            })
        })
        let clientUser = ClientUser(
            userId: "clientUserId",
            profile: .init(nickname: "clientNickname1", bio: "newClientBio", picture: nil))

        _ = try await merger.updateProfileWithClientUser(clientUser, profile: profileWithVariant, userId: "userId")

        let sentUpdate = try #require(userService.lastUpdateProfileData)
        guard case .notUpdated = sentUpdate.nickname else {
            Issue.record("The nickname must not be sent, got \(sentUpdate.nickname)")
            return
        }
        guard case let .updated(hasConfirmedNickname) = sentUpdate.hasConfirmedNickname else {
            Issue.record("The nickname must be confirmed, got \(sentUpdate.hasConfirmedNickname)")
            return
        }
        #expect(hasConfirmedNickname)
        #expect(!sentUpdate.optFindAvailableNickname)
    }
}
