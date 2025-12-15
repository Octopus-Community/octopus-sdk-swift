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
    private let authenticatedCallProvider: AuthenticatedCallProvider
    private let userConfigDatabase: UserConfigDatabase

    /// Failing attempts in a row. Used to delay the next attempt.
    private var nbFailingAttempts = 0
    private var plannedTask: Task<Void, Error>?

    private var cancellable: AnyCancellable?

    init(injector: Injector) {
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        networkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor)
        authenticatedCallProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)
        userConfigDatabase = injector.getInjected(identifiedBy: Injected.userConfigDatabase)
    }

    func start() {
        getCommunityAccessWhenNecessary()
    }

    func stop() {
        cancellable = nil
        plannedTask?.cancel()
        plannedTask = nil
    }

    private func getCommunityAccessWhenNecessary() {
        cancellable = Publishers.CombineLatest(
            userDataStorage.$userData
                .removeDuplicates { $0?.id == $1?.id }
                .filter { $0 != nil },
            networkMonitor.connectionAvailablePublisher
                .first(where: { $0 })
        )
        .sink { [unowned self] _ in
            Task { [weak self] in
                try await self?.getCommunityAccess()
            }
        }
    }

    func getCommunityAccess() async throws {
        nbFailingAttempts = 0
        plannedTask?.cancel()
        plannedTask = nil
        try await doGetCommunityAccess()
    }

    private func doGetCommunityAccess() async throws(ServerCallError) {
        do {
            guard networkMonitor.connectionAvailable else { throw ServerCallError.noNetwork }
            if #available(iOS 14, *) { Logger.profile.trace("Fetching community access") }
            let response = try await remoteClient.userService.canAccessCommunity(authenticationMethod: try authenticatedCallProvider.authenticatedMethod())
            try await userConfigDatabase.upsert(canAccessCommunity: response.canAccessCommunity,
                                                message: response.communityDisabledMessage.nilIfEmpty)
            nbFailingAttempts = 0

            // if everything went well, plan a new call in one day
            Task.detached { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(TimeInterval.days(1) * 1_000_000_000))
                self?.getCommunityAccessWhenNecessary()
            }
        } catch {
            if #available(iOS 14, *) { Logger.profile.debug("Fetching community access failed: \(error)") }
            nbFailingAttempts += 1
            plannedTask = Task {
                try await planGetCommunityAccess(in: Double(nbFailingAttempts) * 5)
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

    private func planGetCommunityAccess(in timeInterval: TimeInterval) async throws {
        let nanoTimeInterval = timeInterval * 1_000_000_000
        guard nanoTimeInterval <= Double(UInt64.max) else { return }
        try await Task.sleep(nanoseconds: UInt64(nanoTimeInterval))
        guard !Task.isCancelled else { return }
        try await doGetCommunityAccess()
    }
}
