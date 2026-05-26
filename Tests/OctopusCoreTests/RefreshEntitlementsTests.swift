//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import XCTest
import Combine
import OctopusDependencyInjection
import OctopusRemoteClient
import OctopusGrpcModels
@testable import OctopusCore

final class RefreshEntitlementsTests: XCTestCase {

    private var injector: Injector!
    private var mockUserService: MockUserService!
    private var userDataStorage: UserDataStorage!
    private var userProfileDatabase: CurrentUserProfileDatabase!
    private var storage = [AnyCancellable]()

    override func setUp() {
        let connectionMode = ConnectionMode.sso(.init(appManagedFields: [], loginRequired: { }, modifyUser: { _ in }))
        injector = Injector()
        injector.register { _ in try! ModelCoreDataStack(inRam: true) }
        injector.register { _ in try! ConfigCoreDataStack(inRam: true) }
        injector.register { CurrentUserProfileDatabase(injector: $0) }
        injector.register { ProfileRepositoryDefault(appManagedFields: [], injector: $0) }
        injector.registerMocks(.remoteClient, .securedStorage, .networkMonitor,
                               .userProfileFetchMonitor, .blockedUserIdsProvider, .appStateMonitor,
                               .magicLinkMonitor)
        injector.register { UserDataStorage(injector: $0) }
        injector.register { AuthenticatedCallProviderDefault(injector: $0) }
        injector.register { PublicProfileDatabase(injector: $0) }
        injector.register { _ in Validators(appManagedFields: []) }
        injector.register { PostFeedsStore(injector: $0) }
        injector.register { CommentFeedsStore(injector: $0) }
        injector.register { ReplyFeedsStore(injector: $0) }
        injector.register { RepliesDatabase(injector: $0) }
        injector.register { CommentsDatabase(injector: $0) }
        injector.register { PostsDatabase(injector: $0) }
        injector.register { FeedItemInfosDatabase(injector: $0) }
        injector.register { ClientUserProvider(connectionMode: connectionMode, injector: $0) }
        injector.register { ClientUserProfileDatabase(injector: $0) }
        injector.register { UserConfigDatabase(injector: $0) }
        injector.register { CommunityConfigDatabase(injector: $0) }
        injector.register { ConfigRepositoryDefault(injector: $0) }
        injector.register { ClientUserProfileMerger(appManagedFields: [], injector: $0) }
        injector.register { FrictionlessProfileMigrator(injector: $0) }
        injector.register { GamificationRepository(injector: $0) }
        injector.register { ToastsRepository(injector: $0) }
        injector.register { SdkEventsEmitter(injector: $0) }

        mockUserService = (injector.getInjected(identifiedBy: Injected.remoteClient)
            .userService as! MockUserService)
        userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        userProfileDatabase = injector.getInjected(identifiedBy: Injected.currentUserProfileDatabase)
    }

    // MARK: - Guard branches

    func testOctopusModeThrowsNotInSSOMode() async throws {
        let repo = MagicLinkConnectionRepository(connectionMode: .octopus(deepLink: nil), injector: injector)
        do {
            try await repo.refreshEntitlements()
            XCTFail("Expected .noClientTokenProvider")
        } catch RefreshEntitlementsCoreError.notInSSOMode {
            // expected
        } catch {
            XCTFail("Expected .noClientTokenProvider, got \(error)")
        }
    }

    func testNoNetworkThrowsNoNetwork() async throws {
        let mockNetworkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor)
            as! MockNetworkMonitor
        mockNetworkMonitor.connectionAvailable = false

        let repo = SSOConnectionRepository(connectionMode: ssoConnectionMode(), injector: injector)
        do {
            try await repo.refreshEntitlements()
            XCTFail("Expected .noNetwork")
        } catch RefreshEntitlementsCoreError.noNetwork {
            // expected
        } catch {
            XCTFail("Expected .noNetwork, got \(error)")
        }
    }

    func testNotConnectedThrowsNotConnected() async throws {
        // No userData, no clientUserData → connectionState is .notConnected
        userDataStorage.store(clientUserData: nil)
        userDataStorage.store(userData: nil)

        let repo = SSOConnectionRepository(connectionMode: ssoConnectionMode(), injector: injector)
        do {
            try await repo.refreshEntitlements()
            XCTFail("Expected .notConnected")
        } catch RefreshEntitlementsCoreError.notConnected {
            // expected
        } catch {
            XCTFail("Expected .notConnected, got \(error)")
        }
    }

    func testGuestThrowsNotConnected() async throws {
        // Guest user is in `.connected` state but `profile.isGuest == true`, which the
        // refreshEntitlements guard should reject with .notConnected.
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "profileId", userId: "userId", nickname: "Guest", isGuest: true))

        let repo = SSOConnectionRepository(connectionMode: ssoConnectionMode(), injector: injector)

        // Wait for connectionState to settle into .connected with guest
        let guestExpectation = XCTestExpectation(description: "Guest connectionState observed")
        repo.$connectionState.sink { state in
            if case let .connected(user, _) = state, user.profile.isGuest {
                guestExpectation.fulfill()
            }
        }.store(in: &storage)
        await fulfillment(of: [guestExpectation], timeout: 15)

        do {
            try await repo.refreshEntitlements()
            XCTFail("Expected .notConnected")
        } catch RefreshEntitlementsCoreError.notConnected {
            // expected
        } catch {
            XCTFail("Expected .notConnected, got \(error)")
        }
    }

    // MARK: - Backend failure mapping
    //
    // Note: a happy-path test (success response → new JWT persisted) would require holding
    // the SSO repo in `.connected(non-guest)` state during the refresh call, which has
    // proven flaky in unit tests due to the multi-step `connectUser` → `connect()` →
    // `getJwt` lifecycle. The two tests below pin the meaningful failure-mapping
    // branches; the success path is exercised by integration with the sample app.

    func testUserBannedMappedFromBackendFailure() async throws {
        let connectionRepository = try await connectAsClientUser()

        mockUserService.injectNextGetJwtFromClientResponse(.with {
            $0.result = .fail(.with { failure in
                failure.errors = [
                    .with { err in
                        err.errorCode = .userBanned
                        err.message = "You are banned."
                    }
                ]
            })
        })

        do {
            try await connectionRepository.refreshEntitlements()
            XCTFail("Expected .userBanned")
        } catch RefreshEntitlementsCoreError.userBanned(let message) {
            XCTAssertEqual(message, "You are banned.")
        } catch {
            XCTFail("Expected .userBanned, got \(error)")
        }
    }

    func testNonBannedFailureMappedToServerError() async throws {
        let connectionRepository = try await connectAsClientUser()

        mockUserService.injectNextGetJwtFromClientResponse(.with {
            $0.result = .fail(.with { failure in
                failure.errors = [
                    .with { err in
                        err.errorCode = .unknownError
                        err.message = "Something went wrong."
                    }
                ]
            })
        })

        do {
            try await connectionRepository.refreshEntitlements()
            XCTFail("Expected .serverError")
        } catch RefreshEntitlementsCoreError.serverError(let underlying) {
            let serverError = try XCTUnwrap(underlying as? RefreshEntitlementsServerError,
                                            "Expected RefreshEntitlementsServerError, got \(underlying)")
            XCTAssertEqual(serverError.messages, ["Something went wrong."])
        } catch {
            XCTFail("Expected .serverError, got \(error)")
        }
    }

    // MARK: - Helpers

    private func ssoConnectionMode() -> ConnectionMode {
        .sso(.init(appManagedFields: [], loginRequired: { }, modifyUser: { _ in }))
    }

    private func setupWithExistingGuestProfile(_ profile: StorableCurrentUserProfile) async throws {
        userDataStorage.store(userData: .init(id: profile.userId, jwtToken: "fakeJwt"))
        XCTAssertNil(userDataStorage.clientUserData)
        try await userProfileDatabase.upsert(profile: profile)
        let inDb = XCTestExpectation(description: "Guest profile in db")
        userProfileDatabase.profilePublisher(userId: profile.userId)
            .replaceError(with: nil)
            .sink {
                if let stored = $0, stored.isGuest { inDb.fulfill() }
            }.store(in: &storage)
        await fulfillment(of: [inDb], timeout: 15)
    }

    /// Brings the SSO repo into a fully connected, non-guest state. Mirrors the setup used
    /// by `SSOConnectionTests.testFromGuestToNonGuestAfterClientUserConnected` — pre-populate
    /// a guest profile in the DB so the repo init does not need a `getGuestJwt` round trip,
    /// then call `connectUser` (which triggers exactly one `getJwt` call we mock here).
    /// Returns the repo ready for subsequent `refreshEntitlements` assertions.
    private func connectAsClientUser() async throws -> SSOConnectionRepository {
        try await setupWithExistingGuestProfile(StorableCurrentUserProfile.create(
            id: "profileId", userId: "userId", nickname: "Guest", isGuest: true))

        // Initial getJwt response for connectUser (guest → authenticated upgrade).
        mockUserService.injectNextGetJwtFromClientResponse(.with {
            $0.result = .success(.with { connectionData in
                connectionData.userID = "userId"
                connectionData.jwt = "initialJwt"
                connectionData.profile = .with { profile in
                    profile.id = "profileId"
                    profile.nickname = "Nick"
                    profile.hasSeenOnboarding_p = true
                    profile.hasAcceptedCgu_p = true
                    profile.hasConfirmedNickname_p = true
                    profile.isGuest = false
                }
            })
        })

        let repo = SSOConnectionRepository(connectionMode: ssoConnectionMode(), injector: injector)
        let connected = XCTestExpectation(description: "User connected (non-guest)")
        repo.$connectionState.sink { state in
            if case let .connected(user, _) = state, !user.profile.isGuest {
                connected.fulfill()
            }
        }.store(in: &storage)

        try await repo.connectUser(
            ClientUser(userId: "clientUserId", profile: .init(nickname: "Nick", bio: nil, picture: nil)),
            tokenProvider: { "fakeClientToken" }
        )
        await fulfillment(of: [connected], timeout: 15)
        return repo
    }
}
