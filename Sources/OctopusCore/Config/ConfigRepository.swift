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

    /// Internal test affordance (exposed via an `@_spi` SDK entry point): locally override the
    /// per-field profile lock of the published community config, without a backend-driven config.
    /// Pass `nil` to clear and fall back to the backend value. Used by the sample app.
    func debugOverrideProfileFieldsLock(_ lock: ProfileFieldsLock?)

    /// Internal test affordance (exposed via an `@_spi` SDK entry point): locally override the
    /// per-content-type content options of the published community config, without a backend-driven
    /// config. Pass `nil` to clear and fall back to the backend value. Used by the sample app.
    func debugOverrideContentOptions(_ options: ContentOptions?)

    /// Internal test affordance (exposed via an `@_spi` SDK entry point): locally override the Unified
    /// Profile activation flag (`exposeClientUserId`) of the published community config, applied on top
    /// of the backend-driven config. Pass `nil` to clear and fall back to the backend value. Used by
    /// the sample app to exercise the feature before the backend serves it.
    func debugOverrideExposeClientUserId(_ enabled: Bool?)
    /// Internal test affordance (exposed via an `@_spi` SDK entry point): locally override the
    /// terms-acceptance mode of the published community config, without a backend-driven config.
    /// Pass `nil` to clear and fall back to the backend value.
    func debugOverrideTermsAcceptanceMode(_ mode: TermsAcceptanceMode?)
    /// Internal test affordance (exposed via an `@_spi` SDK entry point): locally override whether members must
    /// type their nickname before their first contribution, without a backend-driven config. Pass `nil` to clear
    /// and fall back to the backend value.
    func debugOverrideForceNicknameChoice(_ enabled: Bool?)
    /// Internal test affordance (exposed via an `@_spi` SDK entry point): locally override the consent texts of
    /// the published community config, applied on top of the backend-driven config. Pass `nil` to clear and fall
    /// back to the backend value. Used by the sample app.
    func debugOverrideConsentTexts(_ texts: ConsentTexts?)
}

extension Injected {
    static let configRepository = Injector.InjectedIdentifier<ConfigRepository>()
}

class ConfigRepositoryDefault: ConfigRepository, InjectableObject, @unchecked Sendable {
    static let injectedIdentifier = Injected.configRepository

    @Published private(set) var communityConfig: CommunityConfig?
    var communityConfigPublisher: AnyPublisher<CommunityConfig?, Never> { $communityConfig.eraseToAnyPublisher() }

    /// Latest config as delivered by the storage layer (before any test override is applied).
    private var storedCommunityConfig: CommunityConfig?
    private var profileFieldsLockOverride: ProfileFieldsLock?
    private var contentOptionsOverride: ContentOptions?
    private var exposeClientUserIdOverride: Bool?
    private var termsAcceptanceModeOverride: TermsAcceptanceMode?
    private var forceNicknameChoiceOverride: Bool?
    private var consentTextsOverride: ConsentTexts?

    @Published private(set) var userConfig: UserConfig?
    var userConfigPublisher: AnyPublisher<UserConfig?, Never> { $userConfig.eraseToAnyPublisher() }

    private let communityConfigDatabase: CommunityConfigDatabase
    private let userConfigDatabase: UserConfigDatabase
    private let remoteClient: OctopusRemoteClient
    private let networkMonitor: NetworkMonitor
    private let appStateMonitor: AppStateMonitor
    private let userDataStorage: UserDataStorage
    private let authenticatedCallProvider: AuthenticatedCallProvider
    private let userCommunityAccessSyncStore = UserCommunityAccessSyncStore()

    /// Failing attempts in a row. Used to delay the next attempt.
    private var nbFailingAttempts = 0
    private var plannedRefreshCommunityConfig: Task<Void, Error>?

    private var storage: Set<AnyCancellable> = []

    deinit {
        plannedRefreshCommunityConfig?.cancel()
    }

    init(injector: Injector, forceReset: Bool = false) {
        communityConfigDatabase = injector.getInjected(identifiedBy: Injected.communityConfigDatabase)
        userConfigDatabase = injector.getInjected(identifiedBy: Injected.userConfigDatabase)
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        networkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor)
        appStateMonitor = injector.getInjected(identifiedBy: Injected.appStateMonitor)
        userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        authenticatedCallProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)

        // See `PublishedPublishers`: the database sinks below write these values from the main queue, while other
        // objects subscribe to them later from whichever thread builds them (the profile repository does in its init).
        PublishedPublishers.create($communityConfig, $userConfig)

        if forceReset {
            userCommunityAccessSyncStore.clear()
        }

        // because the userConfig.canAccessCommunity can be read by the client,
        // try to synchronously set the correct value in order to have the correct value right after the SDK init.
        if let hasAccessToCommunity = userCommunityAccessSyncStore.hasAccessToCommunity {
            userConfig = UserConfig(canAccessCommunity: hasAccessToCommunity, accessDeniedMessage: nil)
        }

        // The sinks and the task below capture `self` weakly, not unowned: they can run once this repository is gone.
        // Its last reference can go away off the main thread, while the main queue is delivering a database value: a
        // refresh in flight holds the repository until it ends, and a community switch replaces the core off the main
        // actor (`switchCommunity` is nonisolated async). The refresh task can also start after the release.
        communityConfigDatabase
            .configPublisher()
            .sink { [weak self] config in
                guard let self else { return }
                storedCommunityConfig = config
                publishCommunityConfig()
            }.store(in: &storage)

        userConfigDatabase
            .configPublisher()
            .sink { [weak self] config in
                guard let self else { return }
                userConfig = config
                if let config {
                    userCommunityAccessSyncStore.set(hasAccessToCommunity: config.canAccessCommunity)
                }
            }.store(in: &storage)

        Publishers.CombineLatest(
            networkMonitor.connectionAvailablePublisher,
            appStateMonitor.appStatePublisher
        )
        .first(where: { $0 && $1 == .active })
        .sink { [weak self] _ in
            Task { [weak self] in
                do {
                    try await self?.refreshCommunityConfig()
                } catch {
                    if #available(iOS 14, *) {
                        Logger.config.debug("Error while refreshing the community config: \(error)")
                    }
                }
            }
        }.store(in: &storage)
    }

    private func publishCommunityConfig() {
        var config = storedCommunityConfig
        if let profileFieldsLockOverride, let current = config {
            config = current.withProfileFieldsLock(profileFieldsLockOverride)
        }
        if let contentOptionsOverride, let current = config {
            config = current.withContentOptions(contentOptionsOverride)
        }
        if let exposeClientUserIdOverride, let current = config {
            config = current.withExposeClientUserId(exposeClientUserIdOverride)
        }
        if let termsAcceptanceModeOverride, let current = config {
            config = current.withTermsAcceptanceMode(termsAcceptanceModeOverride)
        }
        if let forceNicknameChoiceOverride, let current = config {
            config = current.withForceNicknameChoice(forceNicknameChoiceOverride)
        }
        if let consentTextsOverride, let current = config {
            config = current.withConsentTexts(consentTextsOverride)
        }
        communityConfig = config
    }

    func debugOverrideProfileFieldsLock(_ lock: ProfileFieldsLock?) {
        profileFieldsLockOverride = lock
        publishCommunityConfig()
    }

    func debugOverrideContentOptions(_ options: ContentOptions?) {
        contentOptionsOverride = options
        publishCommunityConfig()
    }

    func debugOverrideExposeClientUserId(_ enabled: Bool?) {
        exposeClientUserIdOverride = enabled
        publishCommunityConfig()
    }

    func debugOverrideTermsAcceptanceMode(_ mode: TermsAcceptanceMode?) {
        termsAcceptanceModeOverride = mode
        publishCommunityConfig()
    }

    func debugOverrideForceNicknameChoice(_ enabled: Bool?) {
        forceNicknameChoiceOverride = enabled
        publishCommunityConfig()
    }

    func debugOverrideConsentTexts(_ texts: ConsentTexts?) {
        consentTextsOverride = texts
        publishCommunityConfig()
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
            let retryDelay = Double(nbFailingAttempts) * 5
            // weak: a released repository stops retrying, instead of being kept alive by the retry it planned.
            plannedRefreshCommunityConfig = Task { [weak self] in
                let nanoseconds = retryDelay * 1_000_000_000
                guard nanoseconds <= Double(UInt64.max) else { return }
                try await Task.sleep(nanoseconds: UInt64(nanoseconds))
                guard !Task.isCancelled else { return }
                try await self?.doRefreshCommunityConfig()
            }
            if let error = error as? RemoteClientError {
                throw .serverError(ServerError(remoteClientError: error))
            } else {
                throw .other(error)
            }
        }
    }
}
