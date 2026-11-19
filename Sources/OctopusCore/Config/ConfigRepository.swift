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

    /// Reads the access to the community and stores it.
    /// - Returns: the access read, `nil` when nothing was read because the community is closed. `userConfig` only
    ///   follows a main queue turn later: a caller that decides on the access uses this value.
    /// - Throws: `.other(SessionEndedError())` when the server says the session is over: that is no access, it is not
    ///   stored, and the session is replaced (`UserConfigDatabase.endedSessionPublisher`).
    @discardableResult
    func refreshCommunityAccess() async throws(ServerCallError) -> UserConfig?
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
    /// Internal test affordance (exposed via an `@_spi` SDK entry point): locally override the languages in which
    /// the SDK texts address members informally, without a backend-driven config. Pass `nil` to clear and fall
    /// back to the backend value. Used by the sample app.
    func debugOverrideInformalLanguages(_ languages: [String]?)
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
    private var informalLanguagesOverride: [String]?

    @Published private(set) var userConfig: UserConfig?
    var userConfigPublisher: AnyPublisher<UserConfig?, Never> { $userConfig.eraseToAnyPublisher() }
    /// Latest user config as delivered by the storage layer, before the closure of the community overrides it.
    private var storedUserConfig: UserConfig?

    private let communityConfigDatabase: CommunityConfigDatabase
    private let userConfigDatabase: UserConfigDatabase
    private let remoteClient: OctopusRemoteClient
    private let networkMonitor: NetworkMonitor
    private let appStateMonitor: AppStateMonitor
    private let userDataStorage: UserDataStorage
    private let authenticatedCallProvider: AuthenticatedCallProvider
    private let closureRepository: CommunityClosureRepository
    private let userCommunityAccessSyncStore: UserCommunityAccessSyncStore

    /// Delays of the retries that follow a failed refresh, before waiting for the app to come back. Bounded: an error
    /// the server keeps returning must not be asked again for as long as the app runs, for every user at once.
    private let quickRetryDelays: [TimeInterval]
    /// Failing attempts in a row. Used to pick the delay of the next quick retry.
    private var nbFailingAttempts = 0
    private var plannedRefreshCommunityConfig: Task<Void, Error>?
    /// The refresh in flight, shared by whoever asks for one meanwhile. Locked: asked from any task.
    private var runningRefresh: Task<Void, Error>?
    private let runningRefreshLock = NSLock()
    /// Armed once the quick retries failed: refreshes again the next time the app is active with network after not
    /// being so.
    private var retryRefreshCommunityConfig: AnyCancellable?
    /// Whether the refresh of an open community's config has started: it is done once per launch.
    private var didStartLaunchRefresh = false
    /// Whether a refresh asked by a call the server refused because the community is closed is running. Read and
    /// written on the main queue.
    private var isRefreshingAfterClosedRefusal = false
    /// The current date. Overridden by tests to reach the date a closed community is checked again.
    var now: () -> Date = Date.init

    private var storage: Set<AnyCancellable> = []

    deinit {
        plannedRefreshCommunityConfig?.cancel()
    }

    /// - Parameter accessSyncStore: the store of the access read synchronously, the standard one when `nil`.
    init(injector: Injector, forceReset: Bool = false, quickRetryDelays: [TimeInterval] = [5, 10],
         accessSyncStore: UserCommunityAccessSyncStore? = nil) {
        self.quickRetryDelays = quickRetryDelays
        userCommunityAccessSyncStore = accessSyncStore ?? UserCommunityAccessSyncStore()
        communityConfigDatabase = injector.getInjected(identifiedBy: Injected.communityConfigDatabase)
        userConfigDatabase = injector.getInjected(identifiedBy: Injected.userConfigDatabase)
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        networkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor)
        appStateMonitor = injector.getInjected(identifiedBy: Injected.appStateMonitor)
        userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        authenticatedCallProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)
        closureRepository = injector.getInjected(identifiedBy: Injected.communityClosureRepository)

        // See `PublishedPublishers`: the database sinks below write these values from the main queue, while other
        // objects subscribe to them later from whichever thread builds them (the profile repository does in its init).
        PublishedPublishers.create($communityConfig, $userConfig)

        if forceReset {
            userCommunityAccessSyncStore.clear()
        }

        // because the userConfig.canAccessCommunity can be read by the client,
        // try to synchronously set the correct value in order to have the correct value right after the SDK init.
        // The reason of a refusal comes with it, for the same reason.
        if let userConfig = userCommunityAccessSyncStore.userConfig {
            storedUserConfig = userConfig
        }
        publishUserConfig()

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
                storedUserConfig = config
                publishUserConfig()
                if let config {
                    userCommunityAccessSyncStore.set(config)
                }
            }.store(in: &storage)

        // The closure changes from the task that received the config, off the main thread: the user config is
        // published on the main queue, as the database values above, for the main-actor view models it feeds.
        closureRepository.closurePublisher
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.publishUserConfig() }
            .store(in: &storage)

        // An open community's config is refreshed once per launch, the first time the app is active with a network. A
        // closed one is checked each time the app becomes active once its date has come, and never before.
        Publishers.CombineLatest(
            networkMonitor.connectionAvailablePublisher,
            appStateMonitor.appStatePublisher
        )
        .map { $0 && $1 == .active }
        .removeDuplicates()
        .filter { $0 }
        .sink { [weak self] _ in
            guard let self else { return }
            if closureRepository.isClosed {
                guard closureRepository.isCheckDue(now: now()) else { return }
            } else {
                guard !didStartLaunchRefresh else { return }
                didStartLaunchRefresh = true
            }
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

        // A community closed while the app runs first shows as calls the server refuses, naming the closure: the
        // config tells until when. On the main queue, as the other sinks that read the closure.
        remoteClient.set(communityClosedHandler: { [weak self] in
            DispatchQueue.main.async { [weak self] in self?.refreshAfterClosedRefusal() }
        })
    }

    private func refreshAfterClosedRefusal() {
        // Calls are blocked while closed: only the check due at its date reaches the server.
        guard !closureRepository.isClosed else { return }
        // The calls running when the community closes are all refused: one refresh answers them all.
        guard !isRefreshingAfterClosedRefusal else { return }
        isRefreshingAfterClosedRefusal = true
        Task { [weak self] in
            do {
                try await self?.refreshCommunityConfig()
            } catch {
                if #available(iOS 14, *) {
                    Logger.config.debug("Error while refreshing the community config after a closed refusal: \(error)")
                }
            }
            DispatchQueue.main.async { [weak self] in self?.isRefreshingAfterClosedRefusal = false }
        }
    }

    /// While the community is closed, the access is the closure message and the reason is its kind, whatever the
    /// store holds: its row can be missing, after a community switch back to it or when the app was killed during the
    /// purge, or hold what the access call stored before the closure.
    private func publishUserConfig() {
        userConfig = closureRepository.closure.map {
            UserConfig(canAccessCommunity: false, accessDeniedMessage: $0.message.nilIfEmpty,
                       noAccessReason: CommunityNoAccessReason(closureKind: $0.kind))
        } ?? storedUserConfig
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
        if let informalLanguagesOverride, let current = config {
            config = current.withInformalLanguages(informalLanguagesOverride)
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

    func debugOverrideInformalLanguages(_ languages: [String]?) {
        informalLanguagesOverride = languages
        publishCommunityConfig()
    }

    /// Launch, the foreground, a language change and a refused call can ask at once: they share the refresh in flight
    /// rather than each sending its `GetConfig`, which would pass the gate again while the community is closed.
    func refreshCommunityConfig() async throws(ServerCallError) {
        do {
            try await sharedRefresh().value
        } catch let error as ServerCallError {
            throw error
        } catch {
            throw .other(error)
        }
    }

    private func sharedRefresh() -> Task<Void, Error> {
        runningRefreshLock.lock()
        defer { runningRefreshLock.unlock() }
        if let runningRefresh { return runningRefresh }
        // weak: a released repository ends the refresh rather than being kept alive by it.
        let refresh = Task { [weak self] in
            defer { self?.endRefresh() }
            try await self?.refreshOnce()
        }
        runningRefresh = refresh
        return refresh
    }

    /// Whether a refresh is in flight. Read by the tests, whose next refresh would otherwise join the launch one.
    var isRefreshInFlight: Bool {
        runningRefreshLock.lock()
        defer { runningRefreshLock.unlock() }
        return runningRefresh != nil
    }

    private func endRefresh() {
        runningRefreshLock.lock()
        defer { runningRefreshLock.unlock() }
        runningRefresh = nil
    }

    private func refreshOnce() async throws(ServerCallError) {
        // A closed community is only checked once its date has come: a language change does not bring it forward.
        // Read here, in the shared refresh: a check that just answered has moved the date.
        if closureRepository.isClosed && !closureRepository.isCheckDue(now: now()) { return }
        nbFailingAttempts = 0
        plannedRefreshCommunityConfig?.cancel()
        plannedRefreshCommunityConfig = nil
        retryRefreshCommunityConfig = nil
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

    @discardableResult
    public func refreshCommunityAccess() async throws(ServerCallError) -> UserConfig? {
        // The access of a closed community is the closure message, published over the stored row: no call.
        guard !closureRepository.isClosed else { return nil }
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        do {
            let session = userDataStorage.userData
            let communityAccessResponse = try await remoteClient.userService.canAccessCommunity(
                authenticationMethod: try authenticatedCallProvider.authenticatedMethod())
            // Closed while the call was in flight: the answer may already tell of the closure, and the row keeps
            // the open community's access for the reopening.
            guard !closureRepository.isClosed else { return nil }
            guard let userConfig = try await userConfigDatabase.store(accessRead: communityAccessResponse,
                                                                      session: session) else {
                throw SessionEndedError()
            }
            return userConfig
        } catch {
            if let error = error as? RemoteClientError {
                throw .serverError(ServerError(remoteClientError: error))
            } else {
                throw .other(error)
            }
        }
    }

    private func doRefreshCommunityConfig() async throws(ServerCallError) {
        do {
            // in the do: a retry that finds no network waits for it to come back, instead of ending the retries
            guard networkMonitor.connectionAvailable else { throw ServerCallError.noNetwork }
            // Only a due check reaches this point while the community is closed: it is the one call let through.
            let response = try await remoteClient.apiKeyService.getConfig(
                bypassingCallsGate: closureRepository.isClosed)
            try await communityConfigDatabase.upsert(config: CommunityConfig(from: response.apiKeyConfig))
            await closureRepository.handle(config: response.apiKeyConfig, now: now())
            nbFailingAttempts = 0
        } catch {
            if let error = error as? RemoteClientError, error.isCallsBlocked {
                // Not sent, so not worth retrying: the community closed meanwhile.
                throw .serverError(ServerError(remoteClientError: error))
            }
            if nbFailingAttempts < quickRetryDelays.count {
                let retryDelay = quickRetryDelays[nbFailingAttempts]
                nbFailingAttempts += 1
                // weak: a released repository stops retrying, instead of being kept alive by the retry it planned.
                plannedRefreshCommunityConfig = Task { [weak self] in
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                    guard !Task.isCancelled else { return }
                    try await self?.doRefreshCommunityConfig()
                }
            } else {
                refreshCommunityConfigWhenTheAppComesBack()
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

    /// Refreshes again once the app is back in the foreground, or the network back, rather than on a timer: a timer
    /// retries an error the server keeps returning for as long as the app runs, for every user at once.
    /// The quick retries start again from there.
    private func refreshCommunityConfigWhenTheAppComesBack() {
        retryRefreshCommunityConfig = appStateMonitor.comesBackPublisher(networkMonitor: networkMonitor)
            .sink { [weak self] _ in
                Task { [weak self] in
                    do {
                        try await self?.refreshCommunityConfig()
                    } catch {
                        if #available(iOS 14, *) {
                            Logger.config.debug("Error while refreshing the community config again: \(error)")
                        }
                    }
                }
            }
    }
}
