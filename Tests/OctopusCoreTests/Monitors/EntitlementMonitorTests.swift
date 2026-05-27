//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import Combine
import OctopusDependencyInjection
@testable import OctopusCore

@MainActor
final class EntitlementMonitorTests {
    private var cancellables: Set<AnyCancellable> = []

    @Test func cachedEmissionAtInitDoesNotTriggerFetch() async throws {
        let profileSubject = CurrentValueSubject<CurrentUserProfile?, Never>(
            makeProfile(entitlements: ["premium"])
        )
        let counter = AsyncCallCounter()

        let monitor = EntitlementMonitor(
            profilePublisher: profileSubject.eraseToAnyPublisher(),
            refresh: { await counter.increment() }
        )
        monitor.start()
        try await Task.sleep(nanoseconds: 100_000_000)

        let finalCount = await counter.count
        #expect(finalCount == 0)
    }

    @Test func identicalEntitlementsDoNotTriggerFetch() async throws {
        let profileSubject = CurrentValueSubject<CurrentUserProfile?, Never>(
            makeProfile(entitlements: ["premium"])
        )
        let counter = AsyncCallCounter()
        let monitor = EntitlementMonitor(
            profilePublisher: profileSubject.eraseToAnyPublisher(),
            refresh: { await counter.increment() }
        )
        monitor.start()
        try await Task.sleep(nanoseconds: 100_000_000)

        profileSubject.send(makeProfile(entitlements: ["premium"]))
        try await Task.sleep(nanoseconds: 100_000_000)

        let finalCount = await counter.count
        #expect(finalCount == 0)
    }

    @Test func changedEntitlementsTriggerFetch() async throws {
        let profileSubject = CurrentValueSubject<CurrentUserProfile?, Never>(
            makeProfile(entitlements: ["premium"])
        )
        let counter = AsyncCallCounter()
        let monitor = EntitlementMonitor(
            profilePublisher: profileSubject.eraseToAnyPublisher(),
            refresh: { await counter.increment() }
        )
        monitor.start()
        try await Task.sleep(nanoseconds: 100_000_000)

        profileSubject.send(makeProfile(entitlements: ["premium", "vip"]))
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(await counter.count == 1)
    }

    @Test func emptyToPopulatedTriggersFetch() async throws {
        let profileSubject = CurrentValueSubject<CurrentUserProfile?, Never>(nil)
        let counter = AsyncCallCounter()
        let monitor = EntitlementMonitor(
            profilePublisher: profileSubject.eraseToAnyPublisher(),
            refresh: { await counter.increment() }
        )
        monitor.start()
        try await Task.sleep(nanoseconds: 100_000_000)

        profileSubject.send(makeProfile(entitlements: ["premium"]))
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(await counter.count == 1)
    }

    @Test func changedEntitlementsEmitsEvent() async throws {
        let profileSubject = CurrentValueSubject<CurrentUserProfile?, Never>(
            makeProfile(entitlements: ["premium"])
        )
        let fetchCounter = AsyncCallCounter()
        let eventCounter = AsyncCallCounter()
        let monitor = EntitlementMonitor(
            profilePublisher: profileSubject.eraseToAnyPublisher(),
            refresh: { await fetchCounter.increment() },
            emitEvent: { Task { await eventCounter.increment() } }
        )
        monitor.start()
        try await Task.sleep(nanoseconds: 100_000_000)

        profileSubject.send(makeProfile(entitlements: ["premium", "vip"]))
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(await eventCounter.count == 1)
        #expect(await fetchCounter.count == 1)
    }

    @Test func identicalEntitlementsDoNotEmitEvent() async throws {
        let profileSubject = CurrentValueSubject<CurrentUserProfile?, Never>(
            makeProfile(entitlements: ["premium"])
        )
        let eventCounter = AsyncCallCounter()
        let monitor = EntitlementMonitor(
            profilePublisher: profileSubject.eraseToAnyPublisher(),
            refresh: { },
            emitEvent: { Task { await eventCounter.increment() } }
        )
        monitor.start()
        try await Task.sleep(nanoseconds: 100_000_000)

        profileSubject.send(makeProfile(entitlements: ["premium"]))
        try await Task.sleep(nanoseconds: 100_000_000)

        let finalCount = await eventCounter.count
        #expect(finalCount == 0)
    }

    @Test func stopHaltsFurtherFetches() async throws {
        let profileSubject = CurrentValueSubject<CurrentUserProfile?, Never>(
            makeProfile(entitlements: ["premium"])
        )
        let counter = AsyncCallCounter()
        let monitor = EntitlementMonitor(
            profilePublisher: profileSubject.eraseToAnyPublisher(),
            refresh: { await counter.increment() }
        )
        monitor.start()
        monitor.stop()

        profileSubject.send(makeProfile(entitlements: ["premium", "vip"]))
        try await Task.sleep(nanoseconds: 100_000_000)

        let finalCount = await counter.count
        #expect(finalCount == 0)
    }

    // MARK: - Helpers

    private func makeProfile(entitlements: Set<String>) -> CurrentUserProfile {
        let injector = Injector()
        injector.register { _ in try! ModelCoreDataStack(inRam: true) }
        injector.register { PostFeedsStore(injector: $0) }
        injector.register { CommentFeedsStore(injector: $0) }
        injector.register { CommentsDatabase(injector: $0) }
        injector.register { ReplyFeedsStore(injector: $0) }
        injector.register { RepliesDatabase(injector: $0) }
        injector.register { PostsDatabase(injector: $0) }
        injector.register { FeedItemInfosDatabase(injector: $0) }
        injector.registerMocks(.remoteClient, .networkMonitor, .authProvider, .blockedUserIdsProvider)
        let postFeedsStore = injector.getInjected(identifiedBy: Injected.postFeedsStore)

        let storable = StorableCurrentUserProfile.create(
            id: "p1",
            userId: "u1",
            nickname: "n",
            entitlements: entitlements
        )
        return CurrentUserProfile(
            storableProfile: storable,
            gamificationLevels: [],
            postFeedsStore: postFeedsStore
        )
    }
}

private actor AsyncCallCounter {
    private(set) var count: Int = 0
    func increment() { count += 1 }
}
