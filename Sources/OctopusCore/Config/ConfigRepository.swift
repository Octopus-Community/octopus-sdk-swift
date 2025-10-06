//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import os
import OctopusRemoteClient
import OctopusDependencyInjection

/// Repository that exposes the different configurations of the SDK
public protocol ConfigRepository: Sendable {
    var communityConfig: CommunityConfig? { get }
    var communityConfigPublisher: AnyPublisher<CommunityConfig?, Never> { get }

    var userConfig: UserConfig? { get }
    var userConfigPublisher: AnyPublisher<UserConfig?, Never> { get }

    func refreshCommunityConfig() async throws(ServerCallError)

    func refreshCommunityAccess() async throws(ServerCallError)
    func overrideCommunityAccess(_ access: Bool) async throws
}

extension Injected {
    static let configRepository = Injector.InjectedIdentifier<ConfigRepository>()
}

class ConfigRepositoryDefault: ConfigRepository, InjectableObject, @unchecked Sendable {
    static let injectedIdentifier = Injected.configRepository

    @Published private(set) var communityConfig: CommunityConfig?
    var communityConfigPublisher: AnyPublisher<CommunityConfig?, Never> { $communityConfig.eraseToAnyPublisher() }

    @Published private(set) var userConfig: UserConfig?
    var userConfigPublisher: AnyPublisher<UserConfig?, Never> { $userConfig.eraseToAnyPublisher() }

    private let communityConfigDatabase: CommunityConfigDatabase
    private let userConfigDatabase: UserConfigDatabase
    private let remoteClient: OctopusRemoteClient
    private let networkMonitor: NetworkMonitor
    private let userDataStorage: UserDataStorage
    private let authenticatedCallProvider: AuthenticatedCallProvider
    private let userCommunityAccessSyncStore = UserCommunityAccessSyncStore()

    /// Failing attempts in a row. Used to delay the next attempt.
    private var nbFailingAttempts = 0
    private var plannedRefreshCommunityConfig: Task<Void, Error>?

    private var storage: Set<AnyCancellable> = []

    init(injector: Injector) {
        communityConfigDatabase = injector.getInjected(identifiedBy: Injected.communityConfigDatabase)
        userConfigDatabase = injector.getInjected(identifiedBy: Injected.userConfigDatabase)
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        networkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor)
        userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        authenticatedCallProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)

        // because the userConfig.canAccessCommunity can be read by the client,
        // try to synchronously set the correct value in order to have the correct value right after the SDK init.
        if let hasAccessToCommunity = userCommunityAccessSyncStore.hasAccessToCommunity {
            userConfig = UserConfig(canAccessCommunity: hasAccessToCommunity, accessDeniedMessage: nil)
        }

        communityConfigDatabase
            .configPublisher()
            .replaceError(with: nil)
            .sink { [unowned self] config in
                communityConfig = config
            }.store(in: &storage)

        userConfigDatabase
            .configPublisher()
            .replaceError(with: nil)
            .sink { [unowned self] config in
                userConfig = config
                if let config {
                    userCommunityAccessSyncStore.set(hasAccessToCommunity: config.canAccessCommunity)
                }
            }.store(in: &storage)

        networkMonitor.connectionAvailablePublisher
            .first(where: { $0 })
            .sink { [unowned self] _ in
                Task {
                    try await refreshCommunityConfig()
                }
            }.store(in: &storage)
    }

    func refreshCommunityConfig() async throws(ServerCallError) {
        nbFailingAttempts = 0
        plannedRefreshCommunityConfig?.cancel()
        plannedRefreshCommunityConfig = nil
        try await doRefreshCommunityConfig()
    }

    public func overrideCommunityAccess(_ access: Bool) async throws {
        guard networkMonitor.connectionAvailable else { throw ServerCallError.noNetwork }
        guard let userData = userDataStorage.userData else { throw InternalError.incorrectState }
        let response = try await remoteClient.userService.bypassABTestingAccess(
            userId: userData.id, canAccessCommunity: access,
            authenticationMethod: try authenticatedCallProvider.authenticatedMethod())
        switch response.result {
        case let .success(success):
            let newUserData = UserDataStorage.UserData(id: userData.id, clientId: userData.clientId, jwtToken: success.jwt)
            userDataStorage.store(userData: newUserData)
            case let .fail(error):
            throw InternalError.explainedError(error.errors.map { $0.message }.joined(separator: "\n"))
            case .none:
            throw InternalError.incorrectState
        }
        try await refreshCommunityAccess()
    }

    public func refreshCommunityAccess() async throws(ServerCallError) {
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        do {
            let communityAccessResponse = try await remoteClient.userService.canAccessCommunity(
                authenticationMethod: try authenticatedCallProvider.authenticatedMethod())
            try await userConfigDatabase.upsert(canAccessCommunity: communityAccessResponse.canAccessCommunity,
                                                message: communityAccessResponse.communityDisabledMessage.nilIfEmpty)
        } catch {
            if let error = error as? RemoteClientError {
                throw .serverError(ServerError(remoteClientError: error))
            } else {
                throw .other(error)
            }
        }
    }

    private func doRefreshCommunityConfig() async throws(ServerCallError) {
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        do {
            let response = try await remoteClient.apiKeyService.getConfig()
            try await communityConfigDatabase.upsert(config: CommunityConfig(from: response.apiKeyConfig))
            nbFailingAttempts = 0
        } catch {
            nbFailingAttempts += 1
            plannedRefreshCommunityConfig = Task {
                try await planRefreshCommunityConfig(in: Double(nbFailingAttempts) * 5)
            }
            if let error = error as? RemoteClientError {
                throw .serverError(ServerError(remoteClientError: error))
            } else {
                throw .other(error)
            }
        }
    }

    private func planRefreshCommunityConfig(in timeInterval: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(timeInterval * 1_000_000_000))
        guard !Task.isCancelled else { return }
        try await doRefreshCommunityConfig()
    }
}
