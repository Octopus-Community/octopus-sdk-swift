//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import os
import OctopusDependencyInjection

extension Injected {
    static let entitlementMonitor = Injector.InjectedIdentifier<EntitlementMonitor>()
}

/// Watches the connected user's entitlements and refreshes the cached content whenever the
/// entitlement set actually changes — by resetting OctoObject update timestamps and refetching
/// the topic list, so the next access re-resolves permissions against the new entitlements.
///
/// Skips the synthetic startup emission of cached state (`dropFirst`) so SDK boot does not
/// unconditionally refresh — preserving today's lazy-fetch behavior. Filters duplicate
/// emissions (`removeDuplicates`) so periodic profile refreshes that return identical
/// entitlements do not trigger redundant work.
class EntitlementMonitor: InjectableObject, @unchecked Sendable {
    public static let injectedIdentifier = Injected.entitlementMonitor

    private let profilePublisher: AnyPublisher<CurrentUserProfile?, Never>
    private let refresh: @Sendable () async throws -> Void
    private let emitEvent: @Sendable () -> Void
    private var storage: Set<AnyCancellable> = []

    init(injector: Injector) {
        let profileRepository = injector.getInjected(identifiedBy: Injected.profileRepository)
        let topicsRepository = injector.getInjected(identifiedBy: Injected.topicsRepository)
        let eventsEmitter = injector.getInjected(identifiedBy: Injected.sdkEventsEmitter)
        let octoObjectsDatabase = injector.getInjected(identifiedBy: Injected.postsDatabase)
        self.profilePublisher = Publishers.CombineLatest(
            profileRepository.profilePublisher,
            profileRepository.hasLoadedProfilePublisher.filter { $0 }
        )
        .map { $0.0 }
        .removeDuplicates()
        .eraseToAnyPublisher()
        // Reset cached `updateTimestamp` on every OctoObject before refetching so the next
        // access re-resolves their permissions through the network instead of returning a
        // stale-but-recent cache hit. The fetchTopics call follows so the topic list is
        // re-resolved against the new entitlement set.
        self.refresh = {
            try await octoObjectsDatabase.resetUpdateTimestamp()
            _ = try await topicsRepository.fetchTopics()
        }
        self.emitEvent = { eventsEmitter.emit(.entitlementsChanged) }
    }

    /// Test-only init: accepts the publisher and closures directly.
    init(
        profilePublisher: AnyPublisher<CurrentUserProfile?, Never>,
        refresh: @escaping @Sendable () async throws -> Void,
        emitEvent: @escaping @Sendable () -> Void = {}
    ) {
        self.profilePublisher = profilePublisher
        self.refresh = refresh
        self.emitEvent = emitEvent
    }

    func start() {
        guard storage.isEmpty else { return }
        profilePublisher
            .map { $0?.entitlements ?? [] }
            .removeDuplicates()
            .dropFirst()
            .sink { [refresh, emitEvent] _ in
                emitEvent()
                Task {
                    do {
                        try await refresh()
                    } catch {
                        if #available(iOS 14, *) {
                            Logger.groups.debug("EntitlementMonitor refresh failed: \(error)")
                        }
                    }
                }
            }
            .store(in: &storage)
    }

    func stop() {
        storage.removeAll()
    }
}
