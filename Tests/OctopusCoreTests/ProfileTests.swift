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

    func testPublicProfileDatabase_getProfile_returnsStoredProfile() async throws {
        try await publicProfileDatabase.upsert(profile: StorableProfile(
            id: "adminProfileId", nickname: "admin", bio: nil, pictureUrl: nil,
            tags: .admin,
            totalMessages: nil, accountCreationDate: nil,
            gamificationLevel: nil,
            descPostFeedId: "", ascPostFeedId: ""))

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
            descPostFeedId: "", ascPostFeedId: ""))

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
