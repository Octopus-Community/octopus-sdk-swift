//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import os
import OctopusGrpcModels
import OctopusRemoteClient
import OctopusDependencyInjection

extension Injected {
    static let communityClosureRepository = Injector.InjectedIdentifier<CommunityClosureRepository>()
}

/// Whether Octopus closed the community, as the last config said.
///
/// While it is closed, every call to the server is blocked, until `nextCheckDate` comes and the config is checked
/// again. Closing purges what was cached and shows the closure message in place of the community.
final class CommunityClosureRepository: InjectableObject, @unchecked Sendable {
    static let injectedIdentifier = Injected.communityClosureRepository

    /// A subject, not `@Published`: `@Published` sends a new value from `willSet`, before storing it, so a subscriber
    /// that hops to the main queue, as most do, could still read the previous `closure` or `isClosed` there, and
    /// nothing would tell it of the new one after. The subject stores the value before sending it, under its lock.
    private let closureSubject: CurrentValueSubject<CommunityClosure?, Never>
    var closure: CommunityClosure? { closureSubject.value }
    var closurePublisher: AnyPublisher<CommunityClosure?, Never> { closureSubject.eraseToAnyPublisher() }
    var isClosed: Bool { closure != nil }

    private let store: CommunityClosureStore
    private let remoteClient: OctopusRemoteClient
    private let purger: CommunityClosurePurger

    init(injector: Injector, store: CommunityClosureStore) {
        self.store = store
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        purger = injector.getInjected(identifiedBy: Injected.communityClosurePurger)
        closureSubject = CurrentValueSubject(store.closure)
        // Synchronously, before anything can send a call.
        remoteClient.set(callsBlocked: closure != nil)
        // The app was killed during the purge, or it failed: what it had not deleted yet would show until reopening.
        if closure != nil && store.isPurgePending {
            Task { [weak self] in await self?.purge() }
        }
    }

    /// Whether the community is closed and the date to check it again has come.
    func isCheckDue(now: Date = Date()) -> Bool {
        guard let closure else { return false }
        return now >= closure.nextCheckDate
    }

    /// Applies what a config just received says about the closure of the community.
    func handle(config: Com_Octopuscommunity_ApiKeyConfig, now: Date = Date()) async {
        guard let newClosure = CommunityClosure(from: config, now: now) else {
            guard isClosed else { return }
            if #available(iOS 14, *) { Logger.config.debug("The community reopened") }
            // What a purge left is the content of an open community again.
            store.set(purgePending: false)
            store.set(nil)
            remoteClient.set(callsBlocked: false)
            closureSubject.send(nil)
            return
        }
        let wasClosed = isClosed
        // Before the closure is stored: a kill between the two would leave a closure whose purge never ran.
        if !wasClosed { store.set(purgePending: true) }
        store.set(newClosure)
        remoteClient.set(callsBlocked: true)
        closureSubject.send(newClosure)
        if !wasClosed, #available(iOS 14, *) {
            Logger.config.debug("The community is closed until \(newClosure.nextCheckDate)")
        }
        // The access row is left alone: `ConfigRepository` shows the closure message over it while closed, and it is
        // the open community's access again, at once, when it reopens.
        if store.isPurgePending {
            await purge()
        }
    }

    /// Kept pending when it fails: the next launch, or the next check, does it again. Every step deletes, so doing it
    /// twice is harmless.
    private func purge() async {
        // Reopened meanwhile: the content is the open community's again.
        guard isClosed else { return }
        do {
            try await purger.purge()
            store.set(purgePending: false)
        } catch {
            if #available(iOS 14, *) { Logger.config.debug("Error while purging the closed community: \(error)") }
        }
    }
}
