//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import Combine
import CoreData
import OctopusDependencyInjection
@testable import OctopusRemoteClient
import OctopusGrpcModels
@testable import OctopusCore

/// A member's total points on their public profile: what is read from the server, what is cached, and how the
/// connected member's own refreshes keep their cached public profile current.
///
/// Serialized like the other CoreData-backed suites: each test builds its own in-RAM `ModelCoreDataStack`, and
/// concurrent model loading can crash.
@Suite(.serialized)
struct MemberTotalPointsTests {
    // MARK: - Reading the public profile

    @Test func aPublicScoreIsKept() {
        let profile = StorableProfile(from: Self.publicProfile(level: 2, score: 1_250))

        #expect(profile.gamificationLevel == 2)
        #expect(profile.gamificationScore == 1_250)
    }

    @Test func aZeroScoreIsAScore() {
        let profile = StorableProfile(from: Self.publicProfile(level: 0, score: 0))

        #expect(profile.gamificationLevel == 0)
        #expect(profile.gamificationScore == 0)
    }

    @Test func aLevelSentWithoutAScoreLeavesTheScoreUnknown() {
        let profile = StorableProfile(from: Self.publicProfile(level: 3, score: nil))

        #expect(profile.gamificationLevel == 3)
        #expect(profile.gamificationScore == nil)
    }

    @Test func noGamificationBlockMeansNeitherLevelNorScore() {
        let profile = StorableProfile(from: Self.publicProfile(level: nil, score: nil))

        #expect(profile.gamificationLevel == nil)
        #expect(profile.gamificationScore == nil)
    }

    // MARK: - Cache

    @Test func theScoreIsStoredAndReadBack() async throws {
        let env = Self.makeEnvironment()
        try await env.publicProfiles.upsert(Self.publicProfile(level: 1, score: 320))

        let stored = try await env.publicProfiles.getProfile(profileId: "member")
        #expect(stored?.gamificationLevel == 1)
        #expect(stored?.gamificationScore == 320)

        // A later fetch without the total forgets the previous one rather than keeping a stale value.
        try await env.publicProfiles.upsert(Self.publicProfile(level: 1, score: nil))
        #expect(try await env.publicProfiles.getProfile(profileId: "member")?.gamificationScore == nil)
    }

    @Test func theGamificationUpdateOnlyTouchesACachedGamifiedProfile() async throws {
        let env = Self.makeEnvironment()
        try await env.publicProfiles.upsert(Self.publicProfile(level: 1, score: 100))
        try await env.publicProfiles.upsert(Self.publicProfile(id: "notGamified", level: nil, score: nil))

        try await env.publicProfiles.updateGamification("member", level: 3, score: 1_400)
        try await env.publicProfiles.updateGamification("notGamified", level: 0, score: 5)
        try await env.publicProfiles.updateGamification("notCached", level: 5, score: 10)

        let member = try await env.publicProfiles.getProfile(profileId: "member")
        #expect(member?.gamificationLevel == 3)
        #expect(member?.gamificationScore == 1_400)
        let notGamified = try await env.publicProfiles.getProfile(profileId: "notGamified")
        #expect(notGamified?.gamificationLevel == nil)
        #expect(notGamified?.gamificationScore == nil)
        #expect(try await env.publicProfiles.getProfile(profileId: "notCached") == nil)
    }

    // MARK: - Connected member

    @Test func aPrivateRefreshUpdatesTheConnectedGamifiedMembersLevelAndTotal() async throws {
        let stored = try await Self.refreshPrivateProfile(publicLevel: 1, privateLevel: 2, isAdmin: false)

        #expect(stored?.gamificationLevel == 2)
        #expect(stored?.gamificationScore == 1_005)
    }

    @Test func aPrivateRefreshKeepsAGamifiedLevelZero() async throws {
        let stored = try await Self.refreshPrivateProfile(publicLevel: 0, privateLevel: 0, isAdmin: false)

        #expect(stored?.gamificationLevel == 0)
        #expect(stored?.gamificationScore == 1_005)
    }

    @Test func aPrivateRefreshCannotTurnGamificationOn() async throws {
        // The server sends the private block even with gamification disabled, with no level (read as 0).
        let stored = try await Self.refreshPrivateProfile(publicLevel: nil, privateLevel: nil, isAdmin: false)

        #expect(stored?.gamificationLevel == nil)
        #expect(stored?.gamificationScore == nil)
    }

    @Test func aPrivateRefreshOfAnAdminClearsTheirGamification() async throws {
        let stored = try await Self.refreshPrivateProfile(publicLevel: 1, privateLevel: 2, isAdmin: true)

        #expect(stored?.gamificationLevel == nil)
        #expect(stored?.gamificationScore == nil)
    }

    @Test func theCoreProfileCarriesTheScore() async throws {
        let env = Self.makeEnvironment()
        try await env.publicProfiles.upsert(Self.publicProfile(level: 1, score: 42))
        let stored = try #require(try await env.publicProfiles.getProfile(profileId: "member"))

        let profile = Profile(storableProfile: stored, gamificationLevels: [], postFeedsStore: env.postFeedsStore)
        #expect(profile.gamificationScore == 42)
    }

    // MARK: - Order of the writes

    /// A public profile requested before the member earned points, answered after the refresh of their private profile
    /// that counts them: its older total must not replace the newer one (100, then 200, then 100 again otherwise).
    @Test func anOlderPublicResponseDoesNotReplaceANewerPrivateTotal() async throws {
        let env = Self.makeEnvironment()
        try await env.publicProfiles.upsert(Self.publicProfile(id: "me", level: 1, score: 100))

        let publicRequestTicket = ProfileGamificationOrder.nextTicket()
        try await env.publicProfiles.updateGamification("me", level: 2, score: 200)
        try await env.publicProfiles.upsert(
            profile: StorableProfile(from: Self.publicProfile(id: "me", nickname: "Renamed", level: 1, score: 100)),
            gamificationTicket: publicRequestTicket)

        let stored = try await env.publicProfiles.getProfile(profileId: "me")
        #expect(stored?.gamificationLevel == 2)
        #expect(stored?.gamificationScore == 200)
        // The rest of the late response is still written.
        #expect(stored?.nickname == "Renamed")
    }

    @Test func anOlderPrivateTotalDoesNotReplaceANewerPublicOne() async throws {
        let env = Self.makeEnvironment()
        try await env.publicProfiles.upsert(Self.publicProfile(id: "me", level: 1, score: 100))

        let privateRequestTicket = ProfileGamificationOrder.nextTicket()
        try await env.publicProfiles.upsert(Self.publicProfile(id: "me", level: 2, score: 300))
        try await env.publicProfiles.updateGamificationOfGamifiedProfile(
            profileId: "me", level: 1, score: 150, gamificationTicket: privateRequestTicket)

        let stored = try await env.publicProfiles.getProfile(profileId: "me")
        #expect(stored?.gamificationLevel == 2)
        #expect(stored?.gamificationScore == 300)
    }

    @Test func aNewerPublicResponseReplacesAnOlderPrivateTotal() async throws {
        let env = Self.makeEnvironment()
        try await env.publicProfiles.upsert(Self.publicProfile(id: "me", level: 1, score: 100))
        try await env.publicProfiles.updateGamification("me", level: 2, score: 200)

        try await env.publicProfiles.upsert(Self.publicProfile(id: "me", level: 2, score: 250))

        #expect(try await env.publicProfiles.getProfile(profileId: "me")?.gamificationScore == 250)
    }

    /// The same interleaving through the repository: the public-profile request is sent, the member's private profile
    /// is refreshed while its answer is held, then the answer arrives. Both fetches that return the profile (those of
    /// the community data) are checked.
    @Test(arguments: [PublicFetch.byProfileId, .byClientUserId])
    func aPublicFetchAnsweredAfterAPrivateRefreshKeepsTheNewerTotal(_ fetch: PublicFetch) async throws {
        let env = Self.makeEnvironment()
        env.userDataStorage.store(userData: UserDataStorage.UserData(id: "userId", jwtToken: "fake_token"))
        try await env.publicProfiles.upsert(Self.publicProfile(id: "me", level: 1, score: 100))
        let hold = ResponseHold()
        env.userService.getPublicProfileHold = { await hold.pass() }
        // A nickname of its own, to tell the response's fields from the cached ones in what the fetch returns.
        let heldResponse = Com_Octopuscommunity_GetPublicProfileResponse.with {
            $0.profile = Self.publicProfile(id: "me", nickname: "Renamed", level: 1, score: 100)
        }
        if fetch == .byClientUserId {
            env.userService.injectNextGetPublicProfileByClientUserIdResponse(heldResponse)
        } else {
            env.userService.injectNextGetPublicProfileResponse(heldResponse)
        }
        let repository = env.repository
        let publicFetch = Task {
            fetch == .byClientUserId
                ? try await repository.fetchProfile(byClientUserId: "host-me")
                : try await repository.fetchProfile(byProfileId: "me")
        }
        try await hold.waitUntilReached()

        env.userService.injectNextGetPrivateProfileResponse(.with {
            $0.profile = .with {
                $0.id = "me"
                $0.nickname = "Member"
                $0.hasConfirmedNickname_p = true
                $0.gamificationScore = .with {
                    $0.level = 1
                    $0.score = 200
                }
            }
        })
        try await env.repository.fetchCurrentUserProfile()
        #expect(try await env.publicProfiles.getProfile(profileId: "me")?.gamificationScore == 200)

        await hold.release()
        let fetched = try await publicFetch.value

        #expect(try await env.publicProfiles.getProfile(profileId: "me")?.gamificationScore == 200)
        // What the community-data publisher reads: the cached profile, still with the newer total.
        let publisher = env.publicProfiles.profilePublisher(profileId: "me")
        let published = try #require(try await Self.firstValue(of: publisher))
        #expect(published?.gamificationScore == 200)
        // The fetch returns the cached profile too, so that it does not disagree with the publisher: the newer total
        // with the response's other fields.
        #expect(fetched?.gamificationScore == 200)
        #expect(fetched?.nickname == "Renamed")
    }

    /// The three public-profile fetches whose request is sent again when the session changes during it.
    enum PublicFetch: CaseIterable, Sendable {
        case refresh, byProfileId, byClientUserId
    }

    /// A public-profile request sent before a private refresh, refused because the session changed meanwhile, then
    /// sent again after that refresh: the replay reads the newer total (300) and must replace the private one (200).
    @Test(arguments: PublicFetch.allCases)
    func aPublicFetchSentAgainAfterAPrivateRefreshWritesItsNewerTotal(_ fetch: PublicFetch) async throws {
        let env = Self.makeEnvironment()
        env.userDataStorage.store(userData: UserDataStorage.UserData(id: "userId", jwtToken: "fake_token"))
        try await env.publicProfiles.upsert(Self.publicProfile(id: "me", level: 1, score: 100))
        let hold = ResponseHold()
        env.userService.getPublicProfileHold = { await hold.pass() }
        let sessionChanged = RemoteClientError.unknown(RefreshingTokenError.userIdNotMatching)
        let replayResponse = Com_Octopuscommunity_GetPublicProfileResponse.with {
            $0.profile = Self.publicProfile(id: "me", level: 1, score: 300)
        }
        if fetch == .byClientUserId {
            env.userService.injectNextGetPublicProfileByClientUserIdError(sessionChanged)
            env.userService.injectNextGetPublicProfileByClientUserIdResponse(replayResponse)
        } else {
            env.userService.injectNextGetPublicProfileError(sessionChanged)
            env.userService.injectNextGetPublicProfileResponse(replayResponse)
        }
        let repository = env.repository
        let publicFetch = Task {
            switch fetch {
            case .refresh: try await repository.fetchProfile(profileId: "me")
            case .byProfileId: _ = try await repository.fetchProfile(byProfileId: "me")
            case .byClientUserId: _ = try await repository.fetchProfile(byClientUserId: "host-me")
            }
        }
        try await hold.waitUntilReached()

        env.userService.injectNextGetPrivateProfileResponse(.with {
            $0.profile = .with {
                $0.id = "me"
                $0.nickname = "Member"
                $0.hasConfirmedNickname_p = true
                $0.gamificationScore = .with {
                    $0.level = 1
                    $0.score = 200
                }
            }
        })
        try await env.repository.fetchCurrentUserProfile()
        #expect(try await env.publicProfiles.getProfile(profileId: "me")?.gamificationScore == 200)

        await hold.release()
        try await publicFetch.value

        #expect(try await env.publicProfiles.getProfile(profileId: "me")?.gamificationScore == 300)
    }

    /// A profile cached again after a purge takes the gamification of its response whatever its ticket, and that ticket
    /// becomes the one to beat: a private total read after that response is not dropped for a write made before the
    /// purge.
    @Test func aProfileCachedAgainAfterAPurgeTakesTheTicketOfItsResponse() async throws {
        let env = Self.makeEnvironment()
        let publicRequestTicket = ProfileGamificationOrder.nextTicket()
        let privateRequestTicket = ProfileGamificationOrder.nextTicket()
        try await env.publicProfiles.upsert(Self.publicProfile(id: "me", level: 1, score: 100))
        try await env.saveContext.performAsync { [context = env.saveContext] in
            try context.fetch(PublicProfileEntity.fetchAll()).forEach { context.delete($0) }
            try context.save()
        }

        try await env.publicProfiles.upsert(
            profile: StorableProfile(from: Self.publicProfile(id: "me", level: 1, score: 150)),
            gamificationTicket: publicRequestTicket)
        #expect(try await env.publicProfiles.getProfile(profileId: "me")?.gamificationScore == 150)
        try await env.publicProfiles.updateGamificationOfGamifiedProfile(
            profileId: "me", level: 2, score: 200, gamificationTicket: privateRequestTicket)

        #expect(try await env.publicProfiles.getProfile(profileId: "me")?.gamificationScore == 200)
    }

    /// Two private refreshes bringing the same new total: the first writes it, the second writes nothing — one save,
    /// one new value for the community data, not a duplicate per refresh.
    @Test func twoIdenticalTotalsAreWrittenOnce() async throws {
        let env = Self.makeEnvironment()
        try await env.publicProfiles.upsert(Self.publicProfile(id: "me", level: 2, score: 100))
        let saves = SaveCounter(context: env.saveContext)
        let emittedScores = Locked<[Int?]>([])
        let subscription = env.publicProfiles.profilePublisher(profileId: "me")
            .sink { profile in
                guard let profile else { return }
                emittedScores.mutate { $0.append(profile.gamificationScore) }
            }
        defer { subscription.cancel() }
        try await expectWithTimeout(emittedScores.value.count == 1)

        try await env.publicProfiles.updateGamification("me", level: 2, score: 200)
        try await env.publicProfiles.updateGamification("me", level: 2, score: 200)
        // Each save is done when its call returns, and the publisher hands its value to the main queue right then.
        await Self.drainMainQueue()

        #expect(saves.numberOfSaves == 1)
        #expect(emittedScores.value == [100, 200])
    }

    // MARK: - Helpers

    private struct Environment {
        let repository: ProfileRepository
        let userService: MockUserService
        let userDataStorage: UserDataStorage
        let publicProfiles: PublicProfileDatabase
        let postFeedsStore: PostFeedsStore
        let saveContext: NSManagedObjectContext
    }

    /// Same dependency graph as `ProfileTests`.
    private static func makeEnvironment() -> Environment {
        let injector = Injector()
        injector.register { _ in try! ModelCoreDataStack(inRam: true) }
        injector.register { CurrentUserProfileDatabase(injector: $0) }
        injector.register { PublicProfileDatabase(injector: $0) }
        injector.registerMocks(.remoteClient, .securedStorage, .networkMonitor, .appStateMonitor,
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
        injector.register { ClientUserProvider(injector: $0) }
        injector.register { ClientUserProfileMerger(appManagedFields: [], injector: $0) }
        injector.register { FrictionlessProfileMigrator(injector: $0) }
        injector.register { GamificationRepository(injector: $0) }
        injector.register { ToastsRepository(injector: $0) }
        injector.register { SdkEventsEmitter(injector: $0) }

        let repository = ProfileRepositoryDefault(appManagedFields: [], injector: injector)
        return Environment(
            repository: repository,
            userService: injector.getInjected(identifiedBy: Injected.remoteClient).userService as! MockUserService,
            userDataStorage: injector.getInjected(identifiedBy: Injected.userDataStorage),
            publicProfiles: injector.getInjected(identifiedBy: Injected.publicProfileDatabase),
            postFeedsStore: injector.getInjected(identifiedBy: Injected.postFeedsStore),
            saveContext: injector.getInjected(identifiedBy: Injected.modelCoreDataStack).saveContext)
    }

    private static func publicProfile(id: String = "member", nickname: String = "Member", level: Int32?, score: Int32?)
    -> Com_Octopuscommunity_PublicProfile {
        .with {
            $0.id = id
            $0.nickname = nickname
            if let level {
                $0.gamificationScore = .with {
                    $0.level = level
                    if let score { $0.score = score }
                }
            }
        }
    }

    /// Caches the connected member's public profile with `publicLevel` (and a score of 100), then refreshes their
    /// private profile, which carries a total of 1005, and returns their cached public profile.
    private static func refreshPrivateProfile(publicLevel: Int32?, privateLevel: Int32?, isAdmin: Bool)
    async throws -> StorableProfile? {
        let env = makeEnvironment()
        env.userDataStorage.store(userData: UserDataStorage.UserData(id: "userId", jwtToken: "fake_token"))
        try await env.publicProfiles.upsert(publicProfile(id: "me", level: publicLevel, score: publicLevel.map { _ in 100 }))

        env.userService.injectNextGetPrivateProfileResponse(.with {
            $0.profile = .with {
                $0.id = "me"
                $0.nickname = "Member"
                $0.hasConfirmedNickname_p = true
                if isAdmin { $0.tags = [.admin] }
                $0.gamificationScore = .with {
                    $0.score = 1_005
                    if let privateLevel { $0.level = privateLevel }
                }
            }
        })
        try await env.repository.fetchCurrentUserProfile()

        return try await env.publicProfiles.getProfile(profileId: "me")
    }

    /// The first value of `publisher`, or nil (and a recorded failure) if none comes within 5 seconds.
    private static func firstValue<Value>(of publisher: AnyPublisher<Value, Never>) async throws -> Value? {
        let value = Locked<Value?>(nil)
        let subscription = publisher.first().sink { value.value = $0 }
        defer { subscription.cancel() }
        try await expectWithTimeout(value.value != nil)
        return value.value
    }

    /// Returns once the main queue has run what was dispatched to it before: the values a publisher delivering on it
    /// had to deliver by then have been delivered.
    private static func drainMainQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }
}

/// Counts the saves of a context.
private final class SaveCounter: @unchecked Sendable {
    private let saves = Locked(0)
    private var observer: NSObjectProtocol?

    var numberOfSaves: Int { saves.value }

    init(context: NSManagedObjectContext) {
        observer = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave, object: context, queue: nil) { [saves] _ in
                saves.mutate { $0 += 1 }
            }
    }

    deinit {
        observer.map { NotificationCenter.default.removeObserver($0) }
    }
}

private extension PublicProfileDatabase {
    /// Stores a public profile read by a request sent now.
    func upsert(_ profile: Com_Octopuscommunity_PublicProfile) async throws {
        try await upsert(profile: StorableProfile(from: profile), gamificationTicket: ProfileGamificationOrder.nextTicket())
    }

    /// Writes a private profile's gamification read by a request sent now.
    func updateGamification(_ profileId: String, level: Int?, score: Int?) async throws {
        try await updateGamificationOfGamifiedProfile(profileId: profileId, level: level, score: score,
                                                      gamificationTicket: ProfileGamificationOrder.nextTicket())
    }
}
