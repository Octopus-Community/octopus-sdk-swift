//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import os
import OctopusDependencyInjection
import OctopusRemoteClient
#if canImport(GRPC)
import GRPC
#else
import GRPCSwift
#endif
import OctopusGrpcModels

extension Injected {
    static let communityAccessMonitor = Injector.InjectedIdentifier<CommunityAccessMonitor>()
}

class CommunityAccessMonitor: InjectableObject, @unchecked Sendable {
    public static let injectedIdentifier = Injected.communityAccessMonitor

    private let remoteClient: OctopusRemoteClient
    private let userDataStorage: UserDataStorage
    private let networkMonitor: NetworkMonitor
    private let appStateMonitor: AppStateMonitor
    private let authenticatedCallProvider: AuthenticatedCallProvider
    private let userConfigDatabase: UserConfigDatabase
    private let closureRepository: CommunityClosureRepository

    /// Delays of the retries that follow a failure, before waiting for the app to come back. Bounded: an error the
    /// server keeps returning must not be asked again for as long as the app runs, for every user at once.
    private let quickRetryDelays: [TimeInterval]
    /// Failing attempts in a row. Used to pick the delay of the next quick retry.
    private var nbFailingAttempts = 0
    private var plannedTask: Task<Void, Error>?

    private var cancellable: AnyCancellable?
    /// Armed once the quick retries failed: asks again the next time the app is active with network after not
    /// being so.
    private var retryCancellable: AnyCancellable?
    /// The delay before the access is asked again after a success.
    var recheckDelay: TimeInterval = .days(1)
    /// Asks the access again after a success. Kept to be cancelled: a stopped monitor must not ask it later.
    private var plannedRecheck: Task<Void, Never>?
    /// The least time between two reads of the access asked by calls the server refused. The calls of a screen are
    /// refused together: one read answers them all.
    var minIntervalBetweenRefusalReads: TimeInterval = 30
    /// Whether the stored access is a refusal. Read and written on the main queue.
    private var storedAccessIsDenied = false
    private var storedAccessCancellable: AnyCancellable?
    /// When a refused call last asked for a read of the access. Read and written on the main queue.
    private var lastRefusalReadDate: Date?
    /// Between `start()` and `stop()`. A call that ends after a stop plans nothing.
    private var isStarted = false

    init(injector: Injector, quickRetryDelays: [TimeInterval] = [5, 10]) {
        self.quickRetryDelays = quickRetryDelays
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        networkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor)
        appStateMonitor = injector.getInjected(identifiedBy: Injected.appStateMonitor)
        authenticatedCallProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)
        userConfigDatabase = injector.getInjected(identifiedBy: Injected.userConfigDatabase)
        closureRepository = injector.getInjected(identifiedBy: Injected.communityClosureRepository)

        storedAccessCancellable = userConfigDatabase.configPublisher()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.storedAccessIsDenied = $0?.canAccessCommunity == false }

        // An access taken away while the app runs (a ban, an exclusion) first shows as calls the server refuses,
        // naming the user's reason: the access tells the rest, and the screens follow it without waiting for the
        // next launch.
        remoteClient.set(accessRefusedHandler: { [weak self] endsSession in
            DispatchQueue.main.async { [weak self] in self?.getCommunityAccessAfterRefusal(endsSession: endsSession) }
        })
    }

    /// - Parameter endsSession: whether the server refused the call because the session is over.
    private func getCommunityAccessAfterRefusal(endsSession: Bool) {
        // Stopped while the community is closed: the closure is what the screens show then.
        guard isStarted, !closureRepository.isClosed, userDataStorage.userData != nil else { return }
        // The calls of a user without access keep being refused (tracking, notifications): the access is known,
        // and the access denied screen reads it again by itself. Not when the session is over: the stored access,
        // the ban of the guest a banned device was given, does not know it, and the session must be replaced.
        guard !storedAccessIsDenied || endsSession else { return }
        if let lastRefusalReadDate,
           Date().timeIntervalSince(lastRefusalReadDate) < minIntervalBetweenRefusalReads {
            return
        }
        lastRefusalReadDate = Date()
        Task { [weak self] in
            do {
                try await self?.getCommunityAccess()
            } catch {
                if #available(iOS 14, *) {
                    Logger.config.debug("Error while getting the community access after a refused call: \(error)")
                }
            }
        }
    }

    func start() {
        isStarted = true
        getCommunityAccessWhenNecessary()
    }

    func stop() {
        isStarted = false
        cancellable = nil
        plannedTask?.cancel()
        plannedTask = nil
        retryCancellable = nil
        plannedRecheck?.cancel()
        plannedRecheck = nil
    }

    private func getCommunityAccessWhenNecessary() {
        cancellable = userDataStorage.$userData
            .removeDuplicates { $0?.id == $1?.id }
            // only do it the first time the app is in foreground and there is internet
            .map { [unowned self] userData in
                return Publishers.CombineLatest(
                    networkMonitor.connectionAvailablePublisher.removeDuplicates(),
                    appStateMonitor.appStatePublisher.removeDuplicates()
                )
                .filter { $0 && $1 == .active }
                .first()
                .map { _ in userData }
            }
            .switchToLatest()
            .filter { $0 != nil }
            .sink { [unowned self] _ in
                Task { [weak self] in
                    do {
                        try await self?.getCommunityAccess()
                    } catch {
                        if #available(iOS 14, *) {
                            Logger.config.debug("Error while getting the community access: \(error)")
                        }
                    }
                }
            }
    }

    func getCommunityAccess() async throws(ServerCallError) {
        nbFailingAttempts = 0
        plannedTask?.cancel()
        plannedTask = nil
        retryCancellable = nil
        try await doGetCommunityAccess()
    }

    private func doGetCommunityAccess() async throws(ServerCallError) {
        do {
            guard networkMonitor.connectionAvailable else { throw ServerCallError.noNetwork }
            if #available(iOS 14, *) { Logger.profile.trace("Fetching community access") }
            let session = userDataStorage.userData
            let response = try await remoteClient.userService.canAccessCommunity(authenticationMethod: try authenticatedCallProvider.authenticatedMethod())
            // Closed while the call was in flight: the answer may already tell of the closure, and the row keeps
            // the open community's access for the reopening.
            guard !closureRepository.isClosed else { return }
            try await userConfigDatabase.store(accessRead: response, session: session)

            // if everything went well, plan a new call in one day
            let recheckDelay = recheckDelay
            plannedRecheck?.cancel()
            guard isStarted else { return }
            plannedRecheck = Task.detached { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(recheckDelay * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self?.getCommunityAccessWhenNecessary()
            }
        } catch {
            if #available(iOS 14, *) { Logger.profile.debug("Fetching community access failed: \(error)") }
            if !isStarted {
                // stopped meanwhile: nothing to plan
            } else if nbFailingAttempts < quickRetryDelays.count {
                let delay = quickRetryDelays[nbFailingAttempts]
                nbFailingAttempts += 1
                plannedTask = Task { [weak self] in
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    try await self?.doGetCommunityAccess()
                }
            } else {
                getCommunityAccessWhenTheAppComesBack()
            }
            if let error = error as? ServerCallError {
                throw error
            } else if let error = error as? RemoteClientError {
                throw .serverError(ServerError(remoteClientError: error))
            } else {
                throw .other(error)
            }
        }
    }

    /// Asks again once the app is back in the foreground, or the network back, rather than on a timer: a timer retries
    /// an error the server keeps returning for as long as the app runs, for every user at once.
    /// The quick retries start again from there.
    private func getCommunityAccessWhenTheAppComesBack() {
        retryCancellable = appStateMonitor.comesBackPublisher(networkMonitor: networkMonitor)
            .sink { [weak self] _ in
                Task { [weak self] in
                    do {
                        try await self?.getCommunityAccess()
                    } catch {
                        if #available(iOS 14, *) {
                            Logger.config.debug("Error while getting the community access again: \(error)")
                        }
                    }
                }
            }
    }
}
