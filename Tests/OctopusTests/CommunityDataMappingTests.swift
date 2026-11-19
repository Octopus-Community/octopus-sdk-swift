//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusDependencyInjection
import OctopusRemoteClient
import OctopusGrpcModels
import SwiftProtobuf
import Combine
@testable import Octopus
@testable import OctopusCore

/// Unit-tests for the mapping + nil-propagation logic behind `OctopusSDK.fetchCommunityData(...)`
/// (Sources/Octopus/OctopusSDK.swift, "Community Data" extension) and `OctopusCommunityData.init(from:)`
/// (Sources/Octopus/OctopusCommunityData.swift), Unified Profile.
///
/// ### Why not drive this through a live `OctopusSDK`
/// `OctopusSDK` cannot be constructed with mocked dependencies for a *running* test: its only public
/// initializer (`OctopusSDK.init(apiKey:connectionMode:configuration:)`) builds a real `OctopusSDKCore`
/// backed by a real `GrpcClient`, and that core's designated initializer unconditionally
/// self-registers every repository into its own private `Injector` — there is no seam for a caller to
/// substitute a mock beforehand (`Injector.register` calls `preconditionFailure` on a second
/// registration of an already-registered identifier). This is a pre-existing, repo-wide limitation, not
/// specific to Community Data: see `Tests/OctopusUITests/GroupListViewModelTests.swift`
/// ("The ViewModel itself requires a full OctopusSDK instance, so the filtering predicate is tested as
/// a pure helper below") and the fact that every *running* `OctopusSDK(apiKey:)` construction in this
/// repo's test suites lives inside a `@Suite(.disabled(...))` compile-only suite (`APITests.swift` in
/// both `OctopusTests` and `OctopusUITests`) rather than an executed one.
///
/// So instead, these tests exercise the exact composition `fetchCommunityData` performs —
/// `ProfileRepository.fetchProfile(byProfileId:/byClientUserId:)` (mocked via the `OctopusCore` DI
/// `Injector`, same pattern as `Tests/OctopusCoreTests/ProfileTests.swift`) followed by
/// `OctopusCommunityData.init(from:)` — which is the entirety of `fetchCommunityData`'s body.
///
/// ### What remains genuinely untested
/// The `communityDataPublisher(clientUserId:/profileId:)` Combine chain itself (the `Deferred` /
/// `Future` / `flatMap` composition in `OctopusSDK.swift`) is not exercised here: it captures
/// `core.profileRepository` directly inside `OctopusSDK`, with no substitution point available from
/// outside. Its "emits nil on a failed/unknown-member lookup" behavior rests on the same
/// `fetchProfile(...)` nil-propagation verified below (`fetchCommunityDataByProfileId_unknownMember_returnsNil`
/// / `fetchCommunityDataByClientUserId_unknownMember_returnsNil`), but the publisher wiring itself
/// (the `Deferred`/`Future`/`flatMap`/`receive(on:)` chain) has no automated coverage. Closing that gap
/// would require adding a testability seam to `OctopusSDK`/`OctopusSDKCore` (e.g. an internal
/// initializer accepting a pre-built `Injector`), which is a larger, riskier change than the minimal,
/// test-only `MockConfigRepository.injectNextRefreshCommunityConfig` shim added alongside these tests —
/// left out of scope here.
///
/// ### Why `.serialized`
/// Like the other CoreData-backed Swift Testing suites (e.g. `CoreDataPublisherTests`): each test
/// builds its own in-RAM `ModelCoreDataStack`, and concurrent `NSManagedObjectModel` loading
/// intermittently crashes with an `NSException` under parallel execution.
@Suite(.serialized)
struct CommunityDataMappingTests {
    // MARK: - Setup (mirrors Tests/OctopusCoreTests/ProfileTests.swift's DI graph)

    private static func makeProfileRepositoryAndMocks()
    -> (repository: ProfileRepository, userService: MockUserService, configRepository: MockConfigRepository) {
        let injector = Injector()
        injector.register { _ in try! ModelCoreDataStack(inRam: true) }
        injector.register { CurrentUserProfileDatabase(injector: $0) }
        injector.register { PublicProfileDatabase(injector: $0) }
        injector.registerMocks(.remoteClient, .securedStorage, .networkMonitor, .appStateMonitor,
                               .userProfileFetchMonitor, .authProvider,
                               .blockedUserIdsProvider, .configRepository)
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
        injector.register { ClientUserProvider(injector: $0) }
        injector.register { ClientUserProfileMerger(appManagedFields: [], injector: $0) }
        injector.register { FrictionlessProfileMigrator(injector: $0) }
        injector.register { GamificationRepository(injector: $0) }
        injector.register { ToastsRepository(injector: $0) }
        injector.register { SdkEventsEmitter(injector: $0) }

        let profileRepository = ProfileRepositoryDefault(appManagedFields: [], injector: injector)
        let mockUserService = injector.getInjected(identifiedBy: Injected.remoteClient)
            .userService as! MockUserService
        let mockConfigRepository = injector.getInjected(
            identifiedBy: Injected.configRepository) as! MockConfigRepository
        return (profileRepository, mockUserService, mockConfigRepository)
    }

    // MARK: - fetchCommunityData(profileId:) composition: unknown member → nil

    @Test func fetchCommunityDataByProfileId_unknownMember_returnsNil() async throws {
        let mocks = Self.makeProfileRepositoryAndMocks()
        // Empty response: no such Octopus profile.
        mocks.userService.injectNextGetPublicProfileResponse(Com_Octopuscommunity_GetPublicProfileResponse())

        // Mirrors OctopusSDK.fetchCommunityData(profileId:)'s exact body.
        let profile = try await mocks.repository.fetchProfile(byProfileId: "unknownId")
        let communityData = profile.map { OctopusCommunityData(from: $0) }

        #expect(communityData == nil)
    }

    // MARK: - fetchCommunityData(clientUserId:) composition: unknown member → nil

    @Test func fetchCommunityDataByClientUserId_unknownMember_returnsNil() async throws {
        let mocks = Self.makeProfileRepositoryAndMocks()
        // Empty response: no member for that client user id (e.g. stale mapping, or the community does
        // not expose client user ids).
        mocks.userService.injectNextGetPublicProfileByClientUserIdResponse(
            Com_Octopuscommunity_GetPublicProfileResponse())

        // Mirrors OctopusSDK.fetchCommunityData(clientUserId:)'s exact body.
        let profile = try await mocks.repository.fetchProfile(byClientUserId: "host-unknown")
        let communityData = profile.map { OctopusCommunityData(from: $0) }

        #expect(communityData == nil)
    }

    // MARK: - Mapping: messageCount / gamification present

    @Test func mapping_messageCountAndGamificationPresent() async throws {
        let mocks = Self.makeProfileRepositoryAndMocks()
        mocks.configRepository.injectNextRefreshCommunityConfig(CommunityConfig(
            forceLoginOnStrongActions: false,
            displayAccountAge: false,
            gamificationConfig: GamificationConfig(
                pointsName: "points", abbrevPointSingular: "pt", abbrevPointPlural: "pts",
                pointsByAction: [:],
                gamificationLevels: [
                    GamificationLevel(level: 3, name: "Gold", startAt: 500, nextLevelAt: nil,
                                      badgeColor: nil, badgeTextColor: nil)
                ]),
            displayConfig: nil,
            profileFieldsLock: .allEditable,
            contentOptions: .allEnabled,
            exposeClientUserId: false,
            termsAcceptanceMode: .implicit,
            showCommentsOnOtherProfiles: false, forceNicknameChoice: false, consentTexts: nil,
            informalLanguages: []))

        mocks.userService.injectNextGetPublicProfileResponse(.with {
            $0.profile = .with {
                $0.id = "octoProfileId"
                $0.nickname = "nickname"
                $0.totalMessages = 42
                $0.gamificationScore = .with {
                    $0.level = 3
                    $0.score = 1_250
                }
            }
        })

        let profile = try await mocks.repository.fetchProfile(byProfileId: "octoProfileId")
        let communityData = try #require(profile.map { OctopusCommunityData(from: $0) })

        #expect(communityData.profileId == "octoProfileId")
        #expect(communityData.messageCount == 42)
        #expect(communityData.gamification?.level == 3)
        #expect(communityData.gamification?.score == 1_250)
    }

    // MARK: - Mapping: total points

    @Test func mapping_scoreByClientUserId() async throws {
        let mocks = Self.makeProfileRepositoryAndMocks()
        mocks.configRepository.injectNextRefreshCommunityConfig(Self.gamifiedConfig(levels: [1]))
        mocks.userService.injectNextGetPublicProfileByClientUserIdResponse(.with {
            $0.profile = .with {
                $0.id = "octoProfileId"
                $0.gamificationScore = .with {
                    $0.level = 1
                    $0.score = 0
                }
            }
        })

        let profile = try await mocks.repository.fetchProfile(byClientUserId: "host-member")
        let communityData = try #require(profile.map { OctopusCommunityData(from: $0) })

        #expect(communityData.profileId == "octoProfileId")
        // A total of zero is a total, not an unknown one.
        #expect(communityData.gamification?.score == 0)
    }

    @Test func mapping_levelWithoutScore_leavesTheScoreUnknown() async throws {
        let mocks = Self.makeProfileRepositoryAndMocks()
        mocks.configRepository.injectNextRefreshCommunityConfig(Self.gamifiedConfig(levels: [2]))
        mocks.userService.injectNextGetPublicProfileResponse(.with {
            $0.profile = .with {
                $0.id = "octoProfileId"
                $0.gamificationScore = .with { $0.level = 2 }
            }
        })

        let profile = try await mocks.repository.fetchProfile(byProfileId: "octoProfileId")
        let communityData = try #require(profile.map { OctopusCommunityData(from: $0) })

        #expect(communityData.gamification?.level == 2)
        #expect(communityData.gamification?.score == nil)
    }

    @Test func mapping_adminTaggedProfile_hasNoGamification() async throws {
        let mocks = Self.makeProfileRepositoryAndMocks()
        mocks.configRepository.injectNextRefreshCommunityConfig(Self.gamifiedConfig(levels: [2]))
        mocks.userService.injectNextGetPublicProfileResponse(.with {
            $0.profile = .with {
                $0.id = "adminId"
                $0.tags = [.admin]
                $0.gamificationScore = .with {
                    $0.level = 2
                    $0.score = 50
                }
            }
        })

        let profile = try await mocks.repository.fetchProfile(byProfileId: "adminId")
        let communityData = try #require(profile.map { OctopusCommunityData(from: $0) })

        #expect(communityData.gamification == nil)
    }

    // A regression fails the test instead of leaving the continuation below waiting forever. The time limit needs
    // iOS 16, newer than the package's deployment target.
    @available(iOS 16, *)
    @Test(.timeLimit(.minutes(1)))
    func publisher_emitsTheCachedScore() async throws {
        let mocks = Self.makeProfileRepositoryAndMocks()
        mocks.configRepository.injectNextRefreshCommunityConfig(Self.gamifiedConfig(levels: [1]))
        mocks.userService.injectNextGetPublicProfileResponse(.with {
            $0.profile = .with {
                $0.id = "octoProfileId"
                $0.gamificationScore = .with {
                    $0.level = 1
                    $0.score = 320
                }
            }
        })
        _ = try await mocks.repository.fetchProfile(byProfileId: "octoProfileId")

        // Mirrors OctopusSDK.communityDataPublisher(profileId:)'s mapping of the cached profile.
        let subscription = SubscriptionBox()
        let communityData = await withCheckedContinuation { continuation in
            subscription.cancellable = mocks.repository.getProfile(profileId: "octoProfileId")
                .compactMap { $0.map { OctopusCommunityData(from: $0) } }
                .filter { $0.gamification != nil }
                .first()
                .sink { continuation.resume(returning: $0) }
        }
        subscription.cancellable = nil

        #expect(communityData.gamification?.level == 1)
        #expect(communityData.gamification?.score == 320)
    }

    // MARK: - Mapping: messageCount / gamification absent

    @Test func mapping_messageCountAndGamificationAbsent() async throws {
        let mocks = Self.makeProfileRepositoryAndMocks()
        // No totalMessages, no gamificationScore on the wire response — the community either does not
        // surface messages counts or has gamification disabled.
        mocks.userService.injectNextGetPublicProfileResponse(.with {
            $0.profile = .with {
                $0.id = "octoProfileId"
                $0.nickname = "nickname"
            }
        })

        let profile = try await mocks.repository.fetchProfile(byProfileId: "octoProfileId")
        let communityData = try #require(profile.map { OctopusCommunityData(from: $0) })

        #expect(communityData.messageCount == nil)
        #expect(communityData.gamification == nil)
    }

    // MARK: - Helpers

    /// Keeps a subscription alive until its single value arrives (`first()` resumes the continuation once).
    private final class SubscriptionBox: @unchecked Sendable {
        var cancellable: AnyCancellable?
    }

    /// A community config whose gamification has the given levels, so the mapped profile resolves its level.
    private static func gamifiedConfig(levels: [Int]) -> CommunityConfig {
        CommunityConfig(
            forceLoginOnStrongActions: false,
            displayAccountAge: false,
            gamificationConfig: GamificationConfig(
                pointsName: "points", abbrevPointSingular: "pt", abbrevPointPlural: "pts",
                pointsByAction: [:],
                gamificationLevels: levels.map {
                    GamificationLevel(level: $0, name: "Level \($0)", startAt: 0, nextLevelAt: nil,
                                      badgeColor: nil, badgeTextColor: nil)
                }),
            displayConfig: nil,
            profileFieldsLock: .allEditable,
            contentOptions: .allEnabled,
            exposeClientUserId: true,
            termsAcceptanceMode: .implicit,
            showCommentsOnOtherProfiles: false, forceNicknameChoice: false, consentTexts: nil,
            informalLanguages: [])
    }
}
