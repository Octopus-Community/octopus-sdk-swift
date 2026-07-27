//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import XCTest
import Combine
import OctopusDependencyInjection
import OctopusRemoteClient
import OctopusGrpcModels
import SwiftProtobuf
@testable import OctopusCore

class ProfileTests: XCTestCase {
    /// Object that is tested
    private var profileRepository: ProfileRepository!

    private var mockUserService: MockUserService!
    private var mockUserProfileFetchMonitor: MockUserProfileFetchMonitor!
    private var mockConfigRepository: MockConfigRepository!
    private var userDataStorage: UserDataStorage!
    private var userProfileDatabase: CurrentUserProfileDatabase!
    private var clientUserProfileDatabase: ClientUserProfileDatabase!
    private var publicProfileDatabase: PublicProfileDatabase!
    private var storage = [AnyCancellable]()

    override func setUp() {
        let injector = Injector()
        injector.register { _ in try! ModelCoreDataStack(inRam: true) }
        injector.register { CurrentUserProfileDatabase(injector: $0) }
        injector.register { PublicProfileDatabase(injector: $0) }
        injector.registerMocks(.remoteClient, .securedStorage, .networkMonitor, .appStateMonitor, .magicLinkMonitor,
                               .userProfileFetchMonitor, .authProvider, .blockedUserIdsProvider, .configRepository)
        injector.register { UserDataStorage(injector: $0) }
        injector.register { _ in Validators(appManagedFields: []) }
        injector.register { PostFeedsStore(injector: $0) }
        injector.register { CommentFeedsStore(injector: $0) }
        injector.register { CommentsDatabase(injector: $0) }
        injector.register { ReplyFeedsStore(injector: $0) }
        injector.register { RepliesDatabase(injector: $0) }
        injector.register { PostsDatabase(injector: $0) }
        injector.register { FeedItemInfosDatabase(injector: $0) }
        injector.register { ClientUserProfileDatabase(injector: $0) }
        injector.register { ClientUserProvider(
            connectionMode: .sso(.init(
                appManagedFields: [], loginRequired: {}, modifyUser: { _ in })),
            injector: $0)
        }
        injector.register { ClientUserProfileMerger(appManagedFields: [], injector: $0) }
        injector.register { FrictionlessProfileMigrator(injector: $0) }
        injector.register { GamificationRepository(injector: $0) }
        injector.register { ToastsRepository(injector: $0) }
        injector.register { SdkEventsEmitter(injector: $0) }

        profileRepository = ProfileRepositoryDefault(appManagedFields: [], injector: injector)
        mockUserService = (injector.getInjected(identifiedBy: Injected.remoteClient)
            .userService as! MockUserService)
        mockUserProfileFetchMonitor = (injector.getInjected(
            identifiedBy: Injected.userProfileFetchMonitor) as! MockUserProfileFetchMonitor)
        mockConfigRepository = (injector.getInjected(
            identifiedBy: Injected.configRepository) as! MockConfigRepository)

        userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        userProfileDatabase = injector.getInjected(identifiedBy: Injected.currentUserProfileDatabase)
        clientUserProfileDatabase = injector.getInjected(identifiedBy: Injected.clientUserProfileDatabase)
        publicProfileDatabase = injector.getInjected(identifiedBy: Injected.publicProfileDatabase)
    }

    func testInitialFetchCurrentUserProfile() async throws {
        // Precondition: user is logged in and a profile is in db
        try await userProfileDatabase.upsert(
            profile: StorableCurrentUserProfile(id: "profileId", userId: "userId", nickname: "nickname",
                                                originalNickname: nil,
                                                email: nil, bio: nil, pictureUrl: nil, tags: [],
                                                totalMessages: nil, accountCreationDate: nil,
                                                gamificationLevel: nil, gamificationScore: nil,
                                                hasSeenOnboarding: nil, hasAcceptedCgu: nil,
                                                hasConfirmedNickname: nil, hasConfirmedBio: nil,
                                                hasConfirmedPicture: nil,
                                                isGuest: true,
                                                notificationBadgeCount: 0,
                                                descPostFeedId: "", ascPostFeedId: "", blockedProfileIds: []))
        userDataStorage.store(userData: UserDataStorage.UserData(id: "userId", jwtToken: "fake_token"))

        let userProfilePublishedExpectation = XCTestExpectation(description: "User published")

        var profile: CurrentUserProfile?
        profileRepository.profilePublisher.sink {
            profile = $0
            guard profile?.id == "profileId" else { return }
            userProfilePublishedExpectation.fulfill()
        }.store(in: &storage)

        await fulfillment(of: [userProfilePublishedExpectation], timeout: 5)
        XCTAssertEqual(profile?.nickname, "nickname")
    }

    func testFetchCurrentUserProfile() async throws {
        // Precondition: user is logged in
        userDataStorage.store(userData: UserDataStorage.UserData(id: "userId", jwtToken: "fake_token"))

        let userProfilePublishedExpectation = XCTestExpectation(description: "User published")

        var profile: CurrentUserProfile?
        profileRepository.profilePublisher.sink {
            profile = $0
            guard profile?.id == "profileId" else { return }
            userProfilePublishedExpectation.fulfill()
        }.store(in: &storage)

        try await assertWithTimeout(profile == nil)

        mockUserService.injectNextGetPrivateProfileResponse(.with {
            $0.profile = .with {
                $0.id = "profileId"
                $0.nickname = "nickname"
                $0.hasConfirmedNickname_p = true
            }
        })

        try await profileRepository.fetchCurrentUserProfile()
        await fulfillment(of: [userProfilePublishedExpectation], timeout: 5)
        XCTAssertEqual(profile?.nickname, "nickname")
    }

    func testProfileCreated() async throws {
        let profileCreatedExpectation = XCTestExpectation(description: "Profile created")
        profileRepository.profilePublisher.sink {
            if $0?.nickname == "nickname" && $0?.bio == "Bio" {
                profileCreatedExpectation.fulfill()
            }
        }.store(in: &storage)

        // start with a connected user but without a profile
        userDataStorage.store(userData: UserDataStorage.UserData(id: "userId", jwtToken: "fake_token"))

        mockUserService.injectNextUpdateProfileResponse(.with {
            $0.result = .success(
                .with {
                    $0.profile = .with {
                        $0.id = "profileId"
                        $0.nickname = "nickname"
                        $0.bio = "Bio"
                    }
                })
        })
        try await profileRepository.updateCurrentUserProfile(with: EditableProfile(nickname: .updated("nickname"),
                                                                                   bio: .updated("Bio")))

        await fulfillment(of: [profileCreatedExpectation], timeout: 5)
    }

    func testProfileUpdate() async throws {
        let profilePresentExpectation = XCTestExpectation(description: "Profile present")
        let profileUpdatedExpectation = XCTestExpectation(description: "Profile updated")

        profileRepository.profilePublisher.sink {
            if let profile = $0, profile.nickname == "nickname" {
                if profile.bio == nil {
                    profilePresentExpectation.fulfill()
                } else if profile.bio == "Bio" {
                    profileUpdatedExpectation.fulfill()
                }
            }
        }.store(in: &storage)

        // start with a connected user
        try await userProfileDatabase.upsert(
            profile: StorableCurrentUserProfile(id: "profileId", userId: "userId", nickname: "nickname",
                                                originalNickname: nil,
                                                email: nil, bio: nil, pictureUrl: nil, tags: [],
                                                totalMessages: nil, accountCreationDate: nil,
                                                gamificationLevel: nil, gamificationScore: nil,
                                                hasSeenOnboarding: nil, hasAcceptedCgu: nil,
                                                hasConfirmedNickname: nil, hasConfirmedBio: nil,
                                                hasConfirmedPicture: nil,
                                                isGuest: true,
                                                notificationBadgeCount: 0,
                                                descPostFeedId: "", ascPostFeedId: "", blockedProfileIds: []))
        userDataStorage.store(userData: UserDataStorage.UserData(id: "userId", jwtToken: "fake_token"))

        await fulfillment(of: [profilePresentExpectation], timeout: 5)

        mockUserService.injectNextUpdateProfileResponse(.with {
            $0.result = .success(
                .with {
                    $0.profile = .with {
                        $0.id = "profileId"
                        $0.nickname = "nickname"
                        $0.bio = "Bio"
                    }
                })
        })
        try await profileRepository.updateCurrentUserProfile(with: EditableProfile(nickname: .unchanged, bio: .updated("Bio")))
        await fulfillment(of: [profileUpdatedExpectation], timeout: 5)
    }

    func testFetchProfile() async throws {
        let profilePublishedExpectation = XCTestExpectation(description: "Profile published")

        var profile: Profile?
        profileRepository.getProfile(profileId: "authorProfileId")
            .replaceError(with: nil)
            .sink {
                profile = $0
                guard profile?.id == "authorProfileId" else { return }
                profilePublishedExpectation.fulfill()
            }.store(in: &storage)

        try await assertWithTimeout(profile == nil)

        mockUserService.injectNextGetPublicProfileResponse(.with {
            $0.profile = .with {
                $0.id = "authorProfileId"
                $0.nickname = "nickname"
            }
        })

        try await profileRepository.fetchProfile(profileId: "authorProfileId")
        await fulfillment(of: [profilePublishedExpectation], timeout: 5)
        XCTAssertEqual(profile?.nickname, "nickname")
    }

    func testFetchProfileByProfileId_returnsAndPersistsProfile() async throws {
        mockUserService.injectNextGetPublicProfileResponse(.with {
            $0.profile = .with {
                $0.id = "octoProfileId"
                $0.nickname = "nickname"
            }
        })

        let fetched = try await profileRepository.fetchProfile(byProfileId: "octoProfileId")

        XCTAssertEqual(fetched?.id, "octoProfileId")
        XCTAssertEqual(fetched?.nickname, "nickname")

        // The profile was upserted into the public-profile database, resolvable by its octopus id.
        let stored = try await publicProfileDatabase.getProfile(profileId: "octoProfileId")
        XCTAssertEqual(stored?.id, "octoProfileId")
    }

    func testFetchProfileByProfileId_emptyResponse_returnsNil() async throws {
        // Empty response (no such profile): return nil rather than upserting a malformed profile.
        mockUserService.injectNextGetPublicProfileResponse(
            Com_Octopuscommunity_GetPublicProfileResponse())

        let fetched = try await profileRepository.fetchProfile(byProfileId: "unknownId")
        XCTAssertNil(fetched)
    }

    func testFetchProfileByProfileId_coldStart_resolvesGamificationFromRefreshedConfig() async throws {
        // Cold start: no community config cached yet (mirrors app launch before any config fetch).
        XCTAssertNil(mockConfigRepository.communityConfig)

        // The mocked cold-start refresh (triggered internally by fetchProfile(byProfileId:)) is what
        // supplies the gamification levels — mirrors a real refreshCommunityConfig() populating the
        // cache for the first time.
        mockConfigRepository.injectNextRefreshCommunityConfig(CommunityConfig(
            forceLoginOnStrongActions: false,
            displayAccountAge: false,
            gamificationConfig: GamificationConfig(
                pointsName: "points", abbrevPointSingular: "pt", abbrevPointPlural: "pts",
                pointsByAction: [:],
                gamificationLevels: [
                    GamificationLevel(level: 2, name: "Silver", startAt: 100, nextLevelAt: nil,
                                      badgeColor: nil, badgeTextColor: nil)
                ]),
            displayConfig: nil,
            profileFieldsLock: .allEditable,
            contentOptions: .allEnabled,
            exposeClientUserId: false,
            termsAcceptanceMode: .implicit))

        mockUserService.injectNextGetPublicProfileResponse(.with {
            $0.profile = .with {
                $0.id = "octoProfileId"
                $0.nickname = "nickname"
                $0.gamificationScore = .with { $0.level = 2 }
            }
        })

        let fetched = try await profileRepository.fetchProfile(byProfileId: "octoProfileId")

        // Without the cold-start guard, this would be nil (indistinguishable from gamification being
        // disabled) because the community config was not cached before the call.
        XCTAssertEqual(fetched?.gamificationLevel?.level, 2)
        XCTAssertEqual(fetched?.gamificationLevel?.name, "Silver")
    }

    func testFetchProfileByClientUserId_returnsAndPersistsProfile() async throws {
        mockUserService.injectNextGetPublicProfileByClientUserIdResponse(.with {
            $0.profile = .with {
                $0.id = "octoProfileId"
                $0.nickname = "nickname"
                $0.clientUserID = "host-42"
            }
        })

        let fetched = try await profileRepository.fetchProfile(byClientUserId: "host-42")

        XCTAssertEqual(fetched?.id, "octoProfileId")
        XCTAssertEqual(fetched?.nickname, "nickname")
        XCTAssertEqual(fetched?.clientUserId, "host-42")

        // The profile was upserted into the public-profile database, resolvable by its octopus id.
        let stored = try await publicProfileDatabase.getProfile(profileId: "octoProfileId")
        XCTAssertEqual(stored?.id, "octoProfileId")
        XCTAssertEqual(stored?.clientUserId, "host-42")
    }

    func testFetchProfileByClientUserId_serverError_throws() async throws {
        // Intentionally do NOT inject a response: MockUserService throws a RemoteClientError,
        // which the repository maps to ServerCallError.serverError (mirrors a FAILED_PRECONDITION
        // from a community that does not expose client user ids).
        var thrown: Error?
        do {
            _ = try await profileRepository.fetchProfile(byClientUserId: "host-unknown")
            XCTFail("Expected fetchProfile(byClientUserId:) to throw a server error")
        } catch {
            thrown = error
        }
        guard let serverCallError = thrown as? ServerCallError else {
            XCTFail("Expected ServerCallError, got \(String(describing: thrown))")
            return
        }
        guard case .serverError = serverCallError else {
            XCTFail("Expected ServerCallError.serverError, got \(serverCallError)")
            return
        }
    }

    func testFetchProfileByClientUserId_emptyResponse_returnsNilWithoutEvictingCache() async throws {
        // Seed an existing public profile in cache.
        try await publicProfileDatabase.upsert(profile: StorableProfile(
            id: "cachedId", nickname: "cached", bio: nil, pictureUrl: nil, tags: [],
            totalMessages: nil, accountCreationDate: nil,
            gamificationLevel: nil,
            descPostFeedId: "", ascPostFeedId: "", clientUserId: nil))

        // Empty response (no member for that client user id).
        mockUserService.injectNextGetPublicProfileByClientUserIdResponse(
            Com_Octopuscommunity_GetPublicProfileResponse())

        let fetched = try await profileRepository.fetchProfile(byClientUserId: "host-unknown")
        XCTAssertNil(fetched)

        // Unlike fetchProfile(profileId:), an empty response must NOT evict anything from the cache.
        let stored = try await publicProfileDatabase.getProfile(profileId: "cachedId")
        XCTAssertEqual(stored?.id, "cachedId")
    }

    func testFetchProfileByClientUserId_coldStart_resolvesGamificationFromRefreshedConfig() async throws {
        // Same cold-start guard as fetchProfile(byProfileId:) — see that test's comment.
        XCTAssertNil(mockConfigRepository.communityConfig)

        mockConfigRepository.injectNextRefreshCommunityConfig(CommunityConfig(
            forceLoginOnStrongActions: false,
            displayAccountAge: false,
            gamificationConfig: GamificationConfig(
                pointsName: "points", abbrevPointSingular: "pt", abbrevPointPlural: "pts",
                pointsByAction: [:],
                gamificationLevels: [
                    GamificationLevel(level: 1, name: "Bronze", startAt: 0, nextLevelAt: 100,
                                      badgeColor: nil, badgeTextColor: nil)
                ]),
            displayConfig: nil,
            profileFieldsLock: .allEditable,
            contentOptions: .allEnabled,
            exposeClientUserId: true,
            termsAcceptanceMode: .implicit))

        mockUserService.injectNextGetPublicProfileByClientUserIdResponse(.with {
            $0.profile = .with {
                $0.id = "octoProfileId"
                $0.nickname = "nickname"
                $0.clientUserID = "host-42"
                $0.gamificationScore = .with { $0.level = 1 }
            }
        })

        let fetched = try await profileRepository.fetchProfile(byClientUserId: "host-42")

        XCTAssertEqual(fetched?.gamificationLevel?.level, 1)
        XCTAssertEqual(fetched?.gamificationLevel?.name, "Bronze")
    }

    func testCurrentUserProfileClientUserIdStampedForNonGuest() async throws {
        // SSO-connected, non-guest profile with a host client id.
        try await userProfileDatabase.upsert(
            profile: StorableCurrentUserProfile(id: "profileId", userId: "userId", nickname: "nickname",
                                                originalNickname: nil,
                                                email: nil, bio: nil, pictureUrl: nil, tags: [],
                                                totalMessages: nil, accountCreationDate: nil,
                                                gamificationLevel: nil, gamificationScore: nil,
                                                hasSeenOnboarding: nil, hasAcceptedCgu: nil,
                                                hasConfirmedNickname: nil, hasConfirmedBio: nil,
                                                hasConfirmedPicture: nil,
                                                isGuest: false,
                                                notificationBadgeCount: 0,
                                                descPostFeedId: "", ascPostFeedId: "", blockedProfileIds: []))
        userDataStorage.store(userData: UserDataStorage.UserData(id: "userId", clientId: "host-7",
                                                                 jwtToken: "fake_token"))

        let published = XCTestExpectation(description: "Profile published with client user id")
        var profile: CurrentUserProfile?
        profileRepository.profilePublisher.sink {
            profile = $0
            if $0?.id == "profileId" { published.fulfill() }
        }.store(in: &storage)

        await fulfillment(of: [published], timeout: 5)
        XCTAssertEqual(profile?.clientUserId, "host-7")
    }

    func testCurrentUserProfileClientUserIdNilForGuest() async throws {
        // Guest profile: even with a host client id on userData, the stamp must stay nil.
        try await userProfileDatabase.upsert(
            profile: StorableCurrentUserProfile(id: "profileId", userId: "userId", nickname: "nickname",
                                                originalNickname: nil,
                                                email: nil, bio: nil, pictureUrl: nil, tags: [],
                                                totalMessages: nil, accountCreationDate: nil,
                                                gamificationLevel: nil, gamificationScore: nil,
                                                hasSeenOnboarding: nil, hasAcceptedCgu: nil,
                                                hasConfirmedNickname: nil, hasConfirmedBio: nil,
                                                hasConfirmedPicture: nil,
                                                isGuest: true,
                                                notificationBadgeCount: 0,
                                                descPostFeedId: "", ascPostFeedId: "", blockedProfileIds: []))
        userDataStorage.store(userData: UserDataStorage.UserData(id: "userId", clientId: "host-7",
                                                                 jwtToken: "fake_token"))

        let published = XCTestExpectation(description: "Guest profile published")
        var profile: CurrentUserProfile?
        profileRepository.profilePublisher.sink {
            profile = $0
            if $0?.id == "profileId" { published.fulfill() }
        }.store(in: &storage)

        await fulfillment(of: [published], timeout: 5)
        XCTAssertNil(profile?.clientUserId)
    }

    func testPublicProfileDatabase_getProfile_returnsStoredProfile() async throws {
        try await publicProfileDatabase.upsert(profile: StorableProfile(
            id: "adminProfileId", nickname: "admin", bio: nil, pictureUrl: nil,
            tags: .admin,
            totalMessages: nil, accountCreationDate: nil,
            gamificationLevel: nil,
            descPostFeedId: "", ascPostFeedId: "", clientUserId: nil))

        let fetched = try await publicProfileDatabase.getProfile(profileId: "adminProfileId")
        XCTAssertEqual(fetched?.id, "adminProfileId")
        XCTAssertTrue(fetched?.tags.contains(.admin) ?? false)

        let missing = try await publicProfileDatabase.getProfile(profileId: "unknownId")
        XCTAssertNil(missing)
    }

    func testBlockUser() async throws {
        // Precondition: user is logged in and a profile is in db
        try await userProfileDatabase.upsert(
            profile: StorableCurrentUserProfile(id: "profileId", userId: "userId", nickname: "nickname",
                                                originalNickname: nil,
                                                email: nil, bio: nil, pictureUrl: nil, tags: [],
                                                totalMessages: nil, accountCreationDate: nil,
                                                gamificationLevel: nil, gamificationScore: nil,
                                                hasSeenOnboarding: nil, hasAcceptedCgu: nil,
                                                hasConfirmedNickname: nil, hasConfirmedBio: nil,
                                                hasConfirmedPicture: nil,
                                                isGuest: true,
                                                notificationBadgeCount: 0,
                                                descPostFeedId: "", ascPostFeedId: "", blockedProfileIds: []))
        userDataStorage.store(userData: UserDataStorage.UserData(id: "userId", jwtToken: "fake_token"))

        // ensure blocked list is empty
        let blockedListEmptyExpectation = XCTestExpectation(description: "Blocked user list is empty")
        let blockedListNonEmptyExpectation = XCTestExpectation(description: "Blocked user list contains the blocked user")

        profileRepository.profilePublisher.sink {
            guard let profile = $0 else { return }
            if profile.blockedProfileIds.isEmpty {
                blockedListEmptyExpectation.fulfill()
            } else if profile.blockedProfileIds.contains(where: { $0 == "blockedUserId" }) {
                blockedListNonEmptyExpectation.fulfill()
            }
        }.store(in: &storage)

        await fulfillment(of: [blockedListEmptyExpectation], timeout: 5)
        try await delay()

        mockUserService.injectNextBlockUserResponse(Com_Octopuscommunity_BlockUserResponse())

        try await profileRepository.blockUser(profileId: "blockedUserId")
        await fulfillment(of: [blockedListNonEmptyExpectation], timeout: 5)
    }

    func testBlockUser_adminTarget_throwsInvalidArgument() async throws {
        // Precondition: current user is logged in
        try await userProfileDatabase.upsert(
            profile: StorableCurrentUserProfile(id: "profileId", userId: "userId", nickname: "nickname",
                                                originalNickname: nil,
                                                email: nil, bio: nil, pictureUrl: nil, tags: [],
                                                totalMessages: nil, accountCreationDate: nil,
                                                gamificationLevel: nil, gamificationScore: nil,
                                                hasSeenOnboarding: nil, hasAcceptedCgu: nil,
                                                hasConfirmedNickname: nil, hasConfirmedBio: nil,
                                                hasConfirmedPicture: nil,
                                                isGuest: true,
                                                notificationBadgeCount: 0,
                                                descPostFeedId: "", ascPostFeedId: "", blockedProfileIds: []))
        userDataStorage.store(userData: UserDataStorage.UserData(id: "userId", jwtToken: "fake_token"))

        // Seed an admin-tagged public profile in cache
        try await publicProfileDatabase.upsert(profile: StorableProfile(
            id: "adminProfileId", nickname: "admin", bio: nil, pictureUrl: nil,
            tags: .admin,
            totalMessages: nil, accountCreationDate: nil,
            gamificationLevel: nil,
            descPostFeedId: "", ascPostFeedId: "", clientUserId: nil))

        // Wait for current-user profile to be published
        let currentUserReady = XCTestExpectation(description: "Current user profile ready")
        profileRepository.profilePublisher.sink {
            if $0?.id == "profileId" { currentUserReady.fulfill() }
        }.store(in: &storage)
        await fulfillment(of: [currentUserReady], timeout: 5)

        // Intentionally DO NOT call mockUserService.injectNextBlockUserResponse:
        // if the guard fails, the mock will throw a "Dev error" which the test will surface.
        await assertBlockUserThrowsInvalidArgument(profileId: "adminProfileId")
    }

    func testBlockUser_selfTarget_throwsInvalidArgument() async throws {
        // Precondition: current user is logged in
        try await userProfileDatabase.upsert(
            profile: StorableCurrentUserProfile(id: "profileId", userId: "userId", nickname: "nickname",
                                                originalNickname: nil,
                                                email: nil, bio: nil, pictureUrl: nil, tags: [],
                                                totalMessages: nil, accountCreationDate: nil,
                                                gamificationLevel: nil, gamificationScore: nil,
                                                hasSeenOnboarding: nil, hasAcceptedCgu: nil,
                                                hasConfirmedNickname: nil, hasConfirmedBio: nil,
                                                hasConfirmedPicture: nil,
                                                isGuest: true,
                                                notificationBadgeCount: 0,
                                                descPostFeedId: "", ascPostFeedId: "", blockedProfileIds: []))
        userDataStorage.store(userData: UserDataStorage.UserData(id: "userId", jwtToken: "fake_token"))

        let currentUserReady = XCTestExpectation(description: "Current user profile ready")
        profileRepository.profilePublisher.sink {
            if $0?.id == "profileId" { currentUserReady.fulfill() }
        }.store(in: &storage)
        await fulfillment(of: [currentUserReady], timeout: 5)

        // Target the current user's own profile id — existing guard must reject.
        await assertBlockUserThrowsInvalidArgument(profileId: "profileId")
    }

    func testFillWithClientUser() async throws {
        // Precondition: user is logged in and a profile is in db
        try await userProfileDatabase.upsert(
            profile: StorableCurrentUserProfile(id: "profileId", userId: "userId", nickname: "nickname",
                                                originalNickname: nil,
                                                email: nil, bio: nil, pictureUrl: nil, tags: [],
                                                totalMessages: nil, accountCreationDate: nil,
                                                gamificationLevel: nil, gamificationScore: nil,
                                                hasSeenOnboarding: nil, hasAcceptedCgu: nil,
                                                hasConfirmedNickname: false, hasConfirmedBio: false,
                                                hasConfirmedPicture: false,
                                                isGuest: false,
                                                notificationBadgeCount: 0,
                                                descPostFeedId: "", ascPostFeedId: "", blockedProfileIds: []))
        userDataStorage.store(userData: UserDataStorage.UserData(id: "userId", clientId: "clientUserId", jwtToken: "fake_token"))
        userDataStorage.store(clientUserData: UserDataStorage.ClientUserData(id: "clientUserId"))

        // ensure blocked list is empty
        let profileUpdatedExpectation = XCTestExpectation(description: "Profile updated with client profile")

        profileRepository.profilePublisher.sink {
            guard let profile = $0 else { return }
            if profile.nickname == "clientNickname", profile.bio == "clientBio" {
                profileUpdatedExpectation.fulfill()
            }
        }.store(in: &storage)

        mockUserService.injectNextUpdateProfileResponse(.with {
            $0.result = .success(
                .with {
                    $0.profile = .with {
                        $0.id = "profileId"
                        $0.nickname = "clientNickname"
                        $0.bio = "clientBio"
                        $0.hasConfirmedNickname_p = false
                        $0.hasConfirmedBio_p = false
                        $0.hasConfirmedPicture_p = false
                    }
                })
        })
        try await clientUserProfileDatabase.upsert(
            profile: .init(nickname: "clientNickname", bio: "clientBio", picture: nil),
            clientUserId: "clientUserId")

        await fulfillment(of: [profileUpdatedExpectation], timeout: 5)
    }

    func testDoNotFillWithClientUserWhenOriginalNicknameIsSame() async throws {
        // Precondition: user is logged in and a profile is in db
        try await userProfileDatabase.upsert(
            profile: StorableCurrentUserProfile(id: "profileId", userId: "userId", nickname: "clientNickname1",
                                                originalNickname: "clientNickname",
                                                email: nil, bio: "clientBio", pictureUrl: nil, tags: [],
                                                totalMessages: nil, accountCreationDate: nil,
                                                gamificationLevel: nil, gamificationScore: nil,
                                                hasSeenOnboarding: nil, hasAcceptedCgu: nil,
                                                hasConfirmedNickname: false, hasConfirmedBio: false,
                                                hasConfirmedPicture: false,
                                                isGuest: false,
                                                notificationBadgeCount: 0,
                                                descPostFeedId: "", ascPostFeedId: "", blockedProfileIds: []))
        userDataStorage.store(userData: UserDataStorage.UserData(id: "userId", clientId: "clientUserId", jwtToken: "fake_token"))
        userDataStorage.store(clientUserData: UserDataStorage.ClientUserData(id: "clientUserId"))

        // ensure blocked list is empty
        let profileUpdatedExpectation = XCTestExpectation(description: "Profile updated with client profile")

        profileRepository.profilePublisher.sink {
            guard let profile = $0 else { return }
            if profile.nickname == "clientNickname1", profile.bio == "clientBio" {
                profileUpdatedExpectation.fulfill()
            }
        }.store(in: &storage)

        // no need to call mockUserService.injectNextUpdateProfileResponse because no network calls should be done

        try await clientUserProfileDatabase.upsert(
            profile: .init(nickname: "clientNickname", bio: "clientBio", picture: nil),
            clientUserId: "clientUserId")

        // add a delay to be sure to catch the error if a network call is done without calling the injectXXX
        try await delay()

        await fulfillment(of: [profileUpdatedExpectation], timeout: 5)
    }

    func testNoLoopWhenFillingProfileWithClientProfile() async throws {
        // Precondition: user is logged in and a profile is in db
        try await userProfileDatabase.upsert(
            profile: StorableCurrentUserProfile(id: "profileId", userId: "userId", nickname: "nickname",
                                                originalNickname: nil,
                                                email: nil, bio: "clientBio", pictureUrl: nil, tags: [],
                                                totalMessages: nil, accountCreationDate: nil,
                                                gamificationLevel: nil, gamificationScore: nil,
                                                hasSeenOnboarding: nil, hasAcceptedCgu: nil,
                                                hasConfirmedNickname: false, hasConfirmedBio: false,
                                                hasConfirmedPicture: false,
                                                isGuest: false,
                                                notificationBadgeCount: 0,
                                                descPostFeedId: "", ascPostFeedId: "", blockedProfileIds: []))
        userDataStorage.store(userData: UserDataStorage.UserData(id: "userId", clientId: "clientUserId", jwtToken: "fake_token"))
        userDataStorage.store(clientUserData: UserDataStorage.ClientUserData(id: "clientUserId"))

        // Mock a response with a different value that the one that was asked to create the loop
        mockUserService.injectNextUpdateProfileResponse(.with {
            $0.result = .success(
                .with {
                    $0.profile = .with {
                        $0.id = "profileId"
                        $0.nickname = "clientNickname1"
                        $0.bio = "clientBio"
                        $0.hasConfirmedNickname_p = false
                        $0.hasConfirmedBio_p = false
                        $0.hasConfirmedPicture_p = false
                    }
                })
        })

        // Mock again a response with a different value that the one that was asked to create the loop
        mockUserService.injectNextUpdateProfileResponse(.with {
            $0.result = .success(
                .with {
                    $0.profile = .with {
                        $0.id = "profileId"
                        $0.nickname = "clientNickname2"
                        $0.bio = "clientBio"
                        $0.hasConfirmedNickname_p = false
                        $0.hasConfirmedBio_p = false
                        $0.hasConfirmedPicture_p = false
                    }
                })
        })

        // Mock again a response with a different value that the one that was asked to create the loop
        mockUserService.injectNextUpdateProfileResponse(.with {
            $0.result = .success(
                .with {
                    $0.profile = .with {
                        $0.id = "profileId"
                        $0.nickname = "clientNickname3"
                        $0.bio = "clientBio"
                        $0.hasConfirmedNickname_p = false
                        $0.hasConfirmedBio_p = false
                        $0.hasConfirmedPicture_p = false
                    }
                })
        })

        // Since the protection agains infinite loop is set to 3, no more calls should be done

        try await clientUserProfileDatabase.upsert(
            profile: .init(nickname: "clientNickname", bio: "clientBio", picture: nil),
            clientUserId: "clientUserId")

        // add a delay to be sure to catch the error if a network call is done without calling the injectXXX
        try await delay()

        if let errorMessage = mockUserService.errorMessage {
            XCTFail(errorMessage)
        }
    }

    private func assertBlockUserThrowsInvalidArgument(profileId: String,
                                                      file: StaticString = #filePath,
                                                      line: UInt = #line) async {
        do {
            try await profileRepository.blockUser(profileId: profileId)
            XCTFail("Expected blockUser(profileId: \(profileId)) to throw", file: file, line: line)
        } catch AuthenticatedActionError.other(let underlying) {
            guard let internalError = underlying as? InternalError,
                  case .invalidArgument = internalError else {
                XCTFail("Expected .other(InternalError.invalidArgument), got underlying=\(String(describing: underlying))",
                        file: file, line: line)
                return
            }
        } catch {
            XCTFail("Expected AuthenticatedActionError.other, got \(error)", file: file, line: line)
        }
    }
}
