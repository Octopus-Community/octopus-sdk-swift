//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusDependencyInjection
import OctopusRemoteClient
import OctopusGrpcModels
@testable import OctopusCore

/// Merges of the host's profile when the app manages the nickname. Serialized: the mergers share the picture they
/// sent last, which is stored in the user defaults.
@Suite(.serialized)
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

    /// An update carrying the host's picture can fail while another one, with the same picture, is being merged: the
    /// picture is not taken for sent until an update carrying it succeeds, so the other one sends it.
    @Test func aPictureIsSentAgainWhileTheUpdateCarryingItFails() async throws {
        let merger = merger
        let userService = userService
        // the merger remembers the picture it sent across launches: one no other test sent
        let picture = Data(UUID().uuidString.utf8)
        defer { merger.clearLatestClientUser() }
        userService.injectNextUpdateProfileError(.timeout)
        userService.injectNextUpdateProfileResponse(.with {
            $0.result = .success(.with { $0.profile = .with { $0.id = "profileId" } })
        })
        // keeps the first update in flight while the second merge reads what was sent
        userService.holdUpdateProfile()
        defer { userService.releaseUpdateProfile() }
        let profile = StorableCurrentUserProfile.create(
            id: "profileId", userId: "userId", nickname: "nickname", hasConfirmedPicture: false)
        let firstClientUser = ClientUser(
            userId: "clientUserId", profile: .init(nickname: "firstNickname", bio: nil, picture: picture))
        let secondClientUser = ClientUser(
            userId: "clientUserId", profile: .init(nickname: "secondNickname", bio: nil, picture: picture))

        let first = Task {
            try await merger.updateProfileWithClientUser(firstClientUser, profile: profile, userId: "userId")
        }
        // the second merge starts while the first update, which takes the failure, is in flight
        try await TaskUtils.wait(for: userService.updateProfileCallCount == 1, timeout: 5)
        let second = Task {
            try await merger.updateProfileWithClientUser(secondClientUser, profile: profile, userId: "userId")
        }
        try await TaskUtils.wait(for: userService.updateProfileCallCount == 2, timeout: 5)
        userService.releaseUpdateProfile()
        _ = try? await first.value
        _ = try await second.value

        #expect(userService.updateProfileCallCount == 2)
        let sentUpdate = try #require(userService.lastUpdateProfileData)
        guard case .updated(.some) = sentUpdate.picture else {
            Issue.record("The picture must be sent, got \(sentUpdate.picture)")
            return
        }
    }

    /// The connection and the profile repository can fill the profile with the same host's profile at the same time,
    /// as when the fetch of the profile stores its migration while the connection fills it: one update is sent,
    /// whose answer both get.
    @Test func concurrentMergesOfTheSameClientUserSendOneUpdate() async throws {
        let updatedProfileResponse = Com_Octopuscommunity_UpdateProfileResponse.with {
            $0.result = .success(.with {
                $0.profile = .with {
                    $0.id = "profileId"
                    $0.nickname = "newClientNickname"
                    $0.bio = "clientBio"
                    $0.hasConfirmedNickname_p = true
                }
            })
        }
        // Two answers, so that a second update shows in the count rather than as a missing response. The first one is
        // held in flight until the second merge joins it.
        userService.injectNextUpdateProfileResponse(updatedProfileResponse)
        userService.injectNextUpdateProfileResponse(updatedProfileResponse)
        userService.holdUpdateProfile()
        defer { userService.releaseUpdateProfile() }
        let clientUser = ClientUser(
            userId: "clientUserId",
            profile: .init(nickname: "newClientNickname", bio: "clientBio", picture: nil))

        let merger = merger
        let profile = profileWithVariant
        let first = Task {
            try await merger.updateProfileWithClientUser(clientUser, profile: profile, userId: "userId")
        }
        // the second merge starts once the first update has been sent
        let userService = userService
        try await TaskUtils.wait(for: userService.updateProfileCallCount == 1, timeout: 5)
        let second = Task {
            try await merger.updateProfileWithClientUser(clientUser, profile: profile, userId: "userId")
        }
        // sending its own update instead, it would never join, and the count would show it
        try await TaskUtils.wait(
            for: merger.joinedUpdatesCount == 1 || userService.updateProfileCallCount == 2, timeout: 5)
        userService.releaseUpdateProfile()
        let firstProfile = try await first.value
        let secondProfile = try await second.value

        #expect(userService.updateProfileCallCount == 1)
        #expect(firstProfile?.nickname == "newClientNickname")
        #expect(secondProfile == firstProfile)
    }
}
