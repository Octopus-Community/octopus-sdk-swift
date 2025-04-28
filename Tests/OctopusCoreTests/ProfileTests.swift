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
    private var storage = [AnyCancellable]()

    override func setUp() {
        let injector = Injector()
        injector.register { _ in try! ModelCoreDataStack(inRam: true) }
        injector.register { CurrentUserProfileDatabase(injector: $0) }
        injector.register { PublicProfileDatabase(injector: $0) }
        injector.registerMocks(.remoteClient, .securedStorage, .networkMonitor, .magicLinkMonitor,
                               .userProfileFetchMonitor, .authProvider, .blockedUserIdsProvider)
        injector.register { UserDataStorage(injector: $0) }
        injector.register { _ in Validators(appManagedFields: []) }
        injector.register { PostFeedsStore(injector: $0) }
        injector.register { CommentFeedsStore(injector: $0) }
        injector.register { CommentsDatabase(injector: $0) }
        injector.register { ReplyFeedsStore(injector: $0) }
        injector.register { RepliesDatabase(injector: $0) }
        injector.register { PostsDatabase(injector: $0) }
        injector.register { FeedItemInfosDatabase(injector: $0) }
        injector.register { ClientUserProvider(connectionMode: .octopus(deepLink: nil), injector: $0) }

        profileRepository = ProfileRepository(appManagedFields: [], injector: injector)
        mockUserService = (injector.getInjected(identifiedBy: Injected.remoteClient)
            .userService as! MockUserService)
        mockUserProfileFetchMonitor = (injector.getInjected(
            identifiedBy: Injected.userProfileFetchMonitor) as! MockUserProfileFetchMonitor)

        userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        userProfileDatabase = injector.getInjected(identifiedBy: Injected.currentUserProfileDatabase)
    }

    func testInitialFetchCurrentUserProfile() async throws {
        // Precondition: user is logged in and a profile is in db
        try await userProfileDatabase.upsert(
            profile: StorableCurrentUserProfile(id: "profileId", userId: "userId", nickname: "nickname",
                                                email: nil, bio: nil, pictureUrl: nil,
                                                descPostFeedId: "", ascPostFeedId: "", blockedProfileIds: []))
        userDataStorage.store(userData: UserDataStorage.UserData(id: "userId", jwtToken: "fake_token"))

        let userProfilePublishedExpectation = XCTestExpectation(description: "User published")

        var profile: CurrentUserProfile?
        profileRepository.$profile.sink {
            profile = $0
            guard profile?.id == "profileId" else { return }
            userProfilePublishedExpectation.fulfill()
        }.store(in: &storage)

        await fulfillment(of: [userProfilePublishedExpectation], timeout: 0.5)
        XCTAssertEqual(profile?.nickname, "nickname")
    }

    func testFetchCurrentUserProfile() async throws {
        // Precondition: user is logged in
        userDataStorage.store(userData: UserDataStorage.UserData(id: "userId", jwtToken: "fake_token"))

        let userProfilePublishedExpectation = XCTestExpectation(description: "User published")

        var profile: CurrentUserProfile?
        profileRepository.$profile.sink {
            profile = $0
            guard profile?.id == "profileId" else { return }
            userProfilePublishedExpectation.fulfill()
        }.store(in: &storage)

        try await delay()
        XCTAssertNil(profile)

        mockUserService.injectNextGetPrivateProfileResponse(.with {
            $0.profile = .with {
                $0.id = "profileId"
                $0.nickname = "nickname"
            }
        })

        try await profileRepository.fetchCurrentUserProfile()
        await fulfillment(of: [userProfilePublishedExpectation], timeout: 0.5)
        XCTAssertEqual(profile?.nickname, "nickname")
    }

    func testProfileCreated() async throws {
        var profile: CurrentUserProfile?
        profileRepository.$profile.sink {
            profile = $0
        }.store(in: &storage)

        // start with a connected user but without a profile
        userDataStorage.store(userData: UserDataStorage.UserData(id: "userId", jwtToken: "fake_token"))

        try await delay()
        XCTAssertNil(profile)

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
        try await profileRepository.createCurrentUserProfile(with: EditableProfile(nickname: .updated("nickname"),
                                                                                   bio: .updated("Bio")))

        try await delay()
        guard let profile else {
            XCTFail("Profile should be non nil")
            return
        }
        XCTAssertEqual(profile.nickname, "nickname")
        XCTAssertEqual(profile.bio, "Bio")
    }

    func testProfileUpdate() async throws {
        var profile: CurrentUserProfile?
        profileRepository.$profile.sink {
            profile = $0
        }.store(in: &storage)

        // start with a connected user
        try await userProfileDatabase.upsert(
            profile: StorableCurrentUserProfile(id: "profileId", userId: "userId", nickname: "nickname",
                                                email: nil, bio: nil, pictureUrl: nil,
                                                descPostFeedId: "", ascPostFeedId: "", blockedProfileIds: []))
        userDataStorage.store(userData: UserDataStorage.UserData(id: "userId", jwtToken: "fake_token"))

        try await delay()
        XCTAssertNotNil(profile)

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
        try await profileRepository.updateCurrentUserProfile(with: EditableProfile(nickname: .notUpdated, bio: .updated("Bio")))

        try await delay()
        guard let profile else {
            XCTFail("Profile should be non nil")
            return
        }
        XCTAssertEqual(profile.nickname, "nickname")
        XCTAssertEqual(profile.bio, "Bio")
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

        try await delay()
        XCTAssertNil(profile)

        mockUserService.injectNextGetPublicProfileResponse(.with {
            $0.profile = .with {
                $0.id = "authorProfileId"
                $0.nickname = "nickname"
            }
        })

        try await profileRepository.fetchProfile(profileId: "authorProfileId")
        await fulfillment(of: [profilePublishedExpectation], timeout: 0.5)
        XCTAssertEqual(profile?.nickname, "nickname")
    }

    func testBlockUser() async throws {
        // Precondition: user is logged in and a profile is in db
        try await userProfileDatabase.upsert(
            profile: StorableCurrentUserProfile(id: "profileId", userId: "userId", nickname: "nickname",
                                                email: nil, bio: nil, pictureUrl: nil,
                                                descPostFeedId: "", ascPostFeedId: "", blockedProfileIds: []))
        userDataStorage.store(userData: UserDataStorage.UserData(id: "userId", jwtToken: "fake_token"))

        // ensure blocked list is empty
        let blockedListEmptyExpectation = XCTestExpectation(description: "Blocked user list is empty")
        let blockedListNonEmptyExpectation = XCTestExpectation(description: "Blocked user list contains the blocked user")

        profileRepository.$profile.sink {
            guard let profile = $0 else { return }
            if profile.blockedProfileIds.isEmpty {
                blockedListEmptyExpectation.fulfill()
            } else if profile.blockedProfileIds.contains(where: { $0 == "blockedUserId" }) {
                blockedListNonEmptyExpectation.fulfill()
            }
        }.store(in: &storage)

        await fulfillment(of: [blockedListEmptyExpectation], timeout: 0.5)
        try await delay()

        mockUserService.injectNextBlockUserResponse(Com_Octopuscommunity_BlockUserResponse())

        try await profileRepository.blockUser(profileId: "blockedUserId")
        await fulfillment(of: [blockedListNonEmptyExpectation], timeout: 0.5)
    }

    // This test will be added later, when we care about profile fetching
//    func testStateIsFetchingProfileWhenNoProfile() async throws {
//        let fetchingProfileExpectation = XCTestExpectation(description: "Profile is fetching")
//
//        // for this test, we work with a local UserRepository because we need to create it after setting the
//        // context: the userData should be already present when the connectionRepository is initialiazed
//        // This is why we recreate an environmnent
//        let injector = Injector()
//        injector.register { _ in try! CoreDataStack(inRam: true) }
//        injector.registerMocks(.remoteClient, .securedStorage, .networkMonitor, .magicLinkMonitor,
//            .userProfileFetchMonitor)
//        injector.register { UserDataStorage(injector: $0) }
//
//        let mockUserProfileFetchMonitor = (injector.getInjected(
//            identifiedBy: Injected.userProfileFetchMonitor) as! MockUserProfileFetchMonitor)
//        let userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
//
//        // precondition: userData is present
//        userDataStorage.store(userData: UserDataStorage.UserData(id: "userId", jwtToken: "abc"))
//        try await delay()
//
//        let connectionRepository = UserRepositoryDefault(injector: injector)
//        connectionRepository.connectionStatePublisher.sink { connectionState in
//            switch connectionState {
//            case .fetchingProfile:
//                fetchingProfileExpectation.fulfill()
//            default: break
//            }
//        }.store(in: &storage)
//
//        await fulfillment(of: [fetchingProfileExpectation], timeout: 0.1)
//    }
}
