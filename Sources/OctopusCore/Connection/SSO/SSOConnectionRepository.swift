//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import os
import OctopusRemoteClient
import OctopusDependencyInjection
import OctopusGrpcModels
#if canImport(GRPC)
import GRPC
#else
import GRPCSwift
#endif

class SSOConnectionRepository: ConnectionRepository, InjectableObject, @unchecked Sendable {
    public static let injectedIdentifier = Injected.connectionRepository

    public var connectionStatePublisher: AnyPublisher<ConnectionState, Never> {
        $connectionState.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
    @Published public private(set) var connectionState: ConnectionState = .notConnected(nil)

    public var clientUserConnected: Bool { userDataStorage.clientUserData != nil }

    public let connectionMode: ConnectionMode
    private let profileRepository: ProfileRepository
    private let userDataStorage: UserDataStorage
    private let remoteClient: OctopusRemoteClient
    private let networkMonitor: NetworkMonitor
    private let userProfileDatabase: CurrentUserProfileDatabase
    private let clientUserProfileDatabase: ClientUserProfileDatabase
    private let authenticatedCallProvider: AuthenticatedCallProvider
    private let configRepository: ConfigRepository
    private let userConfigDatabase: UserConfigDatabase
    private let closureRepository: CommunityClosureRepository
    private let userProfileFetchMonitor: UserProfileFetchMonitor
    private let clientUserProfileMerger: ClientUserProfileMerger
    private let frictionlessProfileMigrator: FrictionlessProfileMigrator

    private var storage: Set<AnyCancellable> = []
    private var connectionStateIsSet = false
    @Published private var isConnecting = false
    @Published private var clientIsConnecting = false
    private var isLoggingOutAfterUnauthenticatedError = false
    private var lastConnectionError: Error?
    /// Guards the writes of `connectionState` and `lastConnectionError`, which go together, and the taking of
    /// `isConnecting`. They are written from the main queue (the sinks on the session, the profile and the access)
    /// and from the connection tasks: unguarded, one could overwrite what the other just wrote, such as a ban by
    /// a state without error. Recursive: `connectionState` publishes from inside the write, on the writing thread.
    private let stateLock = NSRecursiveLock()

    @Published private var isWaitingForCommunityAccessToConnectClient = false
    /// Whether the last exchange of the client user's token stored their migrated profile, which it does unless the
    /// exchange or the migration of the profile fails. Written by `connectWithClientUser`, read right after it by
    /// `connect()`, which only one task runs at a time.
    private var exchangeStoredMigratedProfile = false

    private var clientUserTokenProvider: (() async throws -> String)?

    /// Whether the replacement of a session that is over (a deleted account, an ended session) is running, read and
    /// written under `replacementLock`: two of them asked together (a double tap, two reads of the access) must not
    /// both leave that session.
    private var isReplacingSession = false
    private let replacementLock = NSLock()
    /// When a session the server ended was last replaced. Read and written on the main queue.
    private var lastEndedSessionReplacementDate: Date?
    /// A member's session the server ended before the app gave the token provider in this launch, read and written
    /// under `replacementLock`: `connectUser` replaces it with an exchange, rather than a guest standing in for the
    /// member until then.
    private var endedSessionAwaitingClient: UserDataStorage.UserData?
    /// The least time between two replacements of a session the server ended: the reads of the access that find the
    /// same session ended replace it once, and a server that would end each new session at once is not asked for
    /// another in a loop. An end skipped that way is found again by the next read of the access. Shortened by the
    /// tests.
    var minIntervalBetweenEndedSessionReplacements: TimeInterval = 30

    /// How long `connectUser` waits for an unreadable stored session to become readable. Shortened by the tests.
    var unreadableSessionTimeout: TimeInterval = 5

    init(connectionMode: ConnectionMode, injector: Injector) {
        self.connectionMode = connectionMode
        profileRepository = injector.getInjected(identifiedBy: Injected.profileRepository)
        userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        networkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor)
        userProfileDatabase = injector.getInjected(identifiedBy: Injected.currentUserProfileDatabase)
        clientUserProfileDatabase = injector.getInjected(identifiedBy: Injected.clientUserProfileDatabase)
        authenticatedCallProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)
        configRepository = injector.getInjected(identifiedBy: Injected.configRepository)
        userConfigDatabase = injector.getInjected(identifiedBy: Injected.userConfigDatabase)
        closureRepository = injector.getInjected(identifiedBy: Injected.communityClosureRepository)
        userProfileFetchMonitor = injector.getInjected(identifiedBy: Injected.userProfileFetchMonitor)
        clientUserProfileMerger = injector.getInjected(identifiedBy: Injected.clientUserProfileMerger)
        frictionlessProfileMigrator = injector.getInjected(identifiedBy: Injected.frictionlessProfileMigrator)

        // See `PublishedPublishers`: these values are written from the main queue and from connection tasks, while
        // `$isConnecting` is first read in a closure below and `$connectionState` by observers, on other threads.
        PublishedPublishers.create($connectionState, $isConnecting, $clientIsConnecting,
                                   $isWaitingForCommunityAccessToConnectClient)

        Publishers.CombineLatest(
            userDataStorage.$userData.removeDuplicates()
                .receive(on: DispatchQueue.main),
            // ensure that profile value is not the initial one
            Publishers.CombineLatest(
                profileRepository.profilePublisher,
                profileRepository.hasLoadedProfilePublisher.filter { $0 }
            ).map { $0.0 }.removeDuplicates().receive(on: DispatchQueue.main)
        )
        .map { [weak self] userData, profile in
            guard let self else {
                return Just<(UserDataStorage.UserData?, CurrentUserProfile?)>((nil, nil))
                    .eraseToAnyPublisher()
            }
            return $isConnecting
                .filter { !$0 }
                .map { _ in
                    return (userData, profile)
                }
                .eraseToAnyPublisher()
        }
        .switchToLatest()
        .removeDuplicates { $0 == $1 }
        .receive(on: DispatchQueue.main)
        .sink { [weak self] userData, profile in
            guard let self else { return }
            if let profile = profileRepository.profile, let userData = userDataStorage.userData {
                stateLock.withLock {
                    self.connectionState = .connected(User(profile: profile, jwtToken: userData.jwtToken),
                                                      self.lastConnectionError)
                }
                connectionStateIsSet = true
            }
        }
        .store(in: &storage)

        Publishers.CombineLatest3(
            // An unreadable session is not an absent one: connecting a guest then would replace the user's
            // session as soon as the device is unlocked. Wait for it to be read.
            Publishers.CombineLatest(userDataStorage.$userData, userDataStorage.$sessionIsUnreadable)
                .filter { !$1 }
                .map { $0.0 == nil }
                .removeDuplicates().receive(on: DispatchQueue.main),
            // ensure that profile value is not the initial one
            Publishers.CombineLatest(
                profileRepository.profilePublisher,
                profileRepository.hasLoadedProfilePublisher.filter { $0 }
            ).map { $0.0 == nil }.removeDuplicates().receive(on: DispatchQueue.main),
            networkMonitor.connectionAvailablePublisher.filter { $0 }
        )
        .first()
        .sink { [weak self] userDataIsNil, profileIsNil, _ in
            if profileIsNil && userDataIsNil {
                self?.connectAsync()
            }
        }
        .store(in: &storage)

        // When community access is disabled, connecting the client user can fail before they get a session of their
        // own. Hence, wait for the community access to be enabled to connect them again.
        $isWaitingForCommunityAccessToConnectClient
            .map { [unowned self] in
                guard $0 else {
                    return Empty<Void, Never>().eraseToAnyPublisher()
                }

                // Refused while the access still said the community is open, the one read on the previous launch:
                // it opens once it has closed.
                let waitsForTheCommunityToClose = configRepository.userConfig?.canAccessCommunity ?? false
                return configRepository.userConfigPublisher
                    .map { $0?.canAccessCommunity ?? false }
                    .drop { waitsForTheCommunityToClose && $0 }
                    .filter { $0 }
                    .removeDuplicates()
                    .map { _ in }
                    .eraseToAnyPublisher()
            }
            .switchToLatest()
            .sink { [unowned self] in
                isWaitingForCommunityAccessToConnectClient = false
                connectAsync()
            }.store(in: &storage)

        // The refusal of access no longer stands once the community opens to the user, who has their account: the
        // profile repository sends their profile then.
        configRepository.userConfigPublisher
            .map { $0?.canAccessCommunity ?? false }
            .removeDuplicates()
            .filter { $0 }
            // once the connection running at that moment, if any, has recorded its outcome
            // Weakly: the access can be published while this repository is being released.
            .map { [weak self] _ -> AnyPublisher<Bool, Never> in
                guard let self else { return Empty().eraseToAnyPublisher() }
                return self.$isConnecting.filter { !$0 }.first().eraseToAnyPublisher()
            }
            .switchToLatest()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // A profile still to migrate, or an exchange that failed, is for the connection that follows.
                guard let self else { return }
                stateLock.withLock {
                    guard case let .connected(user, error) = self.connectionState,
                          case .communityAccessDenied? = error as? ConnectionError,
                          !user.profile.isGuest, !user.profile.isFrictionlessMigrationPending else { return }
                    self.lastConnectionError = nil
                    self.connectionState = .connected(user, nil)
                }
            }.store(in: &storage)

        // The ban of a member used to be told by the failure of their exchange only, kept in memory. A banned
        // member now has a stored session: the next launch makes no exchange, and a ban can also be found by a
        // read of the access while the app runs. The stored access tells it in both cases, so that the actions of
        // a banned member stay blocked on its message.
        configRepository.userConfigPublisher
            .map { $0?.banMessage }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] banMessage in
                guard let self else { return }
                if let banMessage {
                    // The access of a guest says nothing about a member: the row can be a previous member's.
                    guard userDataStorage.userData?.clientId != nil else { return }
                    record(Self.banError(message: banMessage))
                } else {
                    clearRecordedBan()
                }
            }.store(in: &storage)

        // The server ends the session of the guest a banned device was given once the account behind it is no
        // longer banned. Nothing is shown for it, and the access of that session is not stored: the session is
        // replaced as soon as a read of the access says so.
        userConfigDatabase.endedSessionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] endedSession in
                guard let self, !closureRepository.isClosed, isSession(of: endedSession),
                      !leaveToConnectUser(endedSession), takeEndedSessionReplacementTurn() else { return }
                Task { [weak self] in
                    do {
                        try await self?.replaceSession(.sessionEnded(endedSession))
                    } catch {
                        if #available(iOS 14, *) {
                            Logger.connection.debug("Error while replacing the ended session: \(error)")
                        }
                    }
                }
            }.store(in: &storage)
    }

    private static func banError(message: String) -> ConnectionError {
        .detailedErrors([.init(from: ExchangeTokenError.DetailedError(reason: .userBanned, message: message))])
    }

    /// Keeps the error of a connection, in the state and for the states to come.
    private func record(_ connectionError: ConnectionError) {
        stateLock.lock()
        defer { stateLock.unlock() }
        switch connectionState {
        case .notConnected:
            connectionState = .notConnected(connectionError)
        case let .connected(user, _):
            connectionState = .connected(user, connectionError)
        }
        lastConnectionError = connectionError
    }

    /// Forgets the ban the state carries, if it carries one.
    private func clearRecordedBan() {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard connectionState.userBannedMessage != nil else { return }
        lastConnectionError = nil
        switch connectionState {
        case .notConnected:
            connectionState = .notConnected(nil)
        case let .connected(user, _):
            connectionState = .connected(user, nil)
        }
    }

    func connectUser(_ user: ClientUser, tokenProvider: @escaping () async throws -> String) async throws {
        clientIsConnecting = true
        defer { clientIsConnecting = false }
        try await waitForReadableSession()
        let previousClientUserId = userDataStorage.clientUserData?.id
        // since connection state is not set immediatly, we need to wait for its first "real" value, not the one that
        // it has been init with. While the community is closed, no connection can set it.
        if !closureRepository.isClosed {
            try? await TaskUtils.wait(for: connectionStateIsSet, timeout: 4)
        }
        var currentState = connectionState
        // if client user changed, logout
        if let previousClientUserId, previousClientUserId != user.userId {
            try await logout()
            try await clientUserProfileDatabase.delete(clientUserId: previousClientUserId)
        }
        let endedSessionLeftForClient = setTokenProvider(tokenProvider)

        // Check if client profile changed before the upsert (for the else branch)
        let existingClientProfile = try? await clientUserProfileDatabase.getProfile(clientUserId: user.userId)

        // Subscribe before the upsert that triggers the Combine-based profile sync
        let syncResultHolder = SyncResultHolder()
        let syncCancellable = profileRepository.profileSyncResultPublisher
            .first()
            .sink { [syncResultHolder] in syncResultHolder.result = $0 }

        try await clientUserProfileDatabase.upsert(profile: user.profile, clientUserId: user.userId)
        if previousClientUserId != user.userId {
            userDataStorage.store(clientUserData: .init(id: user.userId))
        }
        // While the community is closed, the user is kept as above and nothing more: the exchange and the profile
        // sync would be calls. `resumeAfterCommunityReopening()` connects them once it reopens.
        if closureRepository.isClosed {
            syncCancellable.cancel()
            return
        }
        // The session of this member the server ended before this call: replaced with the token provider just given.
        if let endedSessionLeftForClient, endedSessionLeftForClient.clientId == user.userId,
           isSession(of: endedSessionLeftForClient) {
            syncCancellable.cancel()
            try await replaceSession(.sessionEnded(endedSessionLeftForClient))
            return
        }
        // The stored session of a banned member needs no exchange, which is what used to tell the host app about
        // the ban. Read the access once instead, and decide on that answer: the stored one can be out of date.
        // The access read below, when it was: the published one only follows a main queue turn later.
        var accessJustRead: UserConfig?
        if userDataStorage.userData?.clientId == user.userId,
           let storedBanMessage = configRepository.userConfig?.banMessage {
            let session = userDataStorage.userData
            let read: UserConfig?
            do throws(ServerCallError) {
                read = try await configRepository.refreshCommunityAccess()
            } catch {
                guard !error.isSessionEnded else {
                    // The session the ban was stored for is over (the guest a banned device was given, once the
                    // account behind it is no longer banned): replaced with the token provider just given.
                    syncCancellable.cancel()
                    try await replaceSession(.sessionEnded(session))
                    return
                }
                read = nil
            }
            accessJustRead = read
            // Nothing read (the call failed): the stored access is all there is to go by.
            if let banMessage = read == nil ? storedBanMessage : read?.banMessage {
                syncCancellable.cancel()
                let banError = Self.banError(message: banMessage)
                record(banError)
                throw banError
            }
            // The ban was lifted. Its error is not one of this session: it must not ask for a new token.
            clearRecordedBan()
            if case let .connected(currentUser, _) = currentState {
                currentState = .connected(currentUser, nil)
            }
        }
        // if state is not connected to the same user, ask for a token
        let tokenNeeded: Bool
        switch currentState {
        case let .connected(currentUser, error):
            // A profile still to migrate is migrated by the exchange, also on a later launch, with no error left.
            tokenNeeded = previousClientUserId != user.userId || currentUser.profile.isGuest || error != nil
                || currentUser.profile.isFrictionlessMigrationPending
        default:
            tokenNeeded = true
        }
        if tokenNeeded {
            syncCancellable.cancel()
            // since guest connection might be currently happening, wait for it to end
            do {
                try await TaskUtils.wait(for: !isConnecting, timeout: 3)
            } catch {
                throw ConnectionError.unknown(error)
            }
            try await connect()
        } else {
            // Check if client profile actually changed — if not, no sync will happen
            if existingClientProfile == user.profile {
                syncCancellable.cancel()
                return
            }

            // Check conditions that would prevent the Combine pipeline from firing
            guard networkMonitor.connectionAvailable else {
                syncCancellable.cancel()
                throw ConnectionError.profileUpdateError(.serverCall(.noNetwork))
            }
            guard (accessJustRead ?? configRepository.userConfig)?.canAccessCommunity ?? false else {
                syncCancellable.cancel()
                throw ConnectionError.communityAccessDenied
            }

            // Wait for the Combine-based sync to complete (timeout = no sync needed, merger found no diff)
            try? await TaskUtils.wait(for: syncResultHolder.result != nil, timeout: 5)
            syncCancellable.cancel()

            if case let .failure(error) = syncResultHolder.result {
                throw ConnectionError.profileUpdateError(error)
            }
        }
    }

    func disconnectUser() async throws {
        guard userDataStorage.clientUserData != nil else { return }
        clientIsConnecting = true
        defer { clientIsConnecting = false }
        let keptGuestSession = try await performLogout()
        // A guest session stays as it is: connecting again would forge a new guest for nothing.
        guard !keptGuestSession else { return }
        connectAsync()
    }

    func logout() async throws {
        try await performLogout()
    }

    func logoutBeforeCommunitySwitch() async throws {
        try await performLogout(keepingGuestSession: false)
    }

    /// Logs the client user out, and returns whether the session was a guest one that was kept as it is.
    /// - Parameter keepingGuestSession: whether a guest session survives the logout. Only a community switch drops
    ///   it: a guest JWT is only valid on the community that issued it.
    @discardableResult
    private func performLogout(keepingGuestSession: Bool = true) async throws -> Bool {
        // Read once, before the first suspension: the guest decision and the profile to delete must describe the
        // same state, whatever changes while the client profile is deleted.
        let state = connectionState
        let guestUser: User? = if case let .connected(user, _) = state, isGuestSession(user) { user } else { nil }
        // The stored session can be ahead of the state: its profile goes with it too.
        let storedUserId = userDataStorage.userData?.id
        // The client user is forgotten whatever the session is. It can be a guest one: when the exchange of the
        // client token fails, the SDK falls back to a guest but keeps the client user to connect them later.
        // Keeping them past a logout would let the next connection sign that very user back in, so a disconnect
        // would end up connecting them. Android forgets the client user before its guest guard too.
        let previousClientUserId = userDataStorage.clientUserData?.id
        self.clientUserTokenProvider = nil
        isWaitingForCommunityAccessToConnectClient = false
        userDataStorage.store(clientUserData: nil)
        // The error a guest session carries is the one of that client user's failed exchange, a ban included: it
        // goes with them, or a guest with no client user any more would still be told they are banned. Android
        // clears the ban with the client user.
        if let guestUser, previousClientUserId != nil, case let .connected(_, error) = state, error != nil {
            stateLock.withLock {
                self.lastConnectionError = nil
                self.connectionState = .connected(guestUser, nil)
            }
        }
        if let previousClientUserId {
            try await clientUserProfileDatabase.delete(clientUserId: previousClientUserId)
        }
        // A guest has no account to log out from. Destroying its identity would re-forge a brand-new
        // guest (user_id churn), so a guest session is kept — matching Android's `!isGuest` guard. Except on a
        // community switch, where the guest belongs to the community being left, as Android's `reset()` clears it.
        if guestUser != nil && keepingGuestSession { return true }
        let profileId: String? = if case let .connected(user, _) = state {
            user.profile.id
        } else { nil }
        userDataStorage.store(userData: nil)
        if let profileId {
            try await profileRepository.deleteCurrentUserProfile(profileId: profileId)
        }
        if let storedUserId, storedUserId != state.user?.profile.userId {
            try await userProfileDatabase.delete(userId: storedUserId)
        }
        return false
    }

    /// The stored session says who is connected. Before the device's first unlock it cannot be read, and taking it
    /// for an absent one would end in a guest connected over it: try to read it for a little while, without
    /// relying on the unlock notification having been received, then give up rather than guess. The host connects
    /// the user again on a later launch or foreground.
    private func waitForReadableSession() async throws {
        // Uptime rather than the wall clock, which network time can set back right after a reboot.
        let deadline = ProcessInfo.processInfo.systemUptime + unreadableSessionTimeout
        while !userDataStorage.readSessionIfUnreadable() {
            guard ProcessInfo.processInfo.systemUptime < deadline else {
                throw ConnectionError.unknown(
                    InternalError.explainedError("The stored session cannot be read until the device is unlocked"))
            }
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }

    private func connectAsync() {
        Task {
            // since guest connection might be currently happening, wait for it to end
            try? await TaskUtils.wait(for: !isConnecting)
            try? await connect()
        }
    }

    /// Connects what the closure of the community left unconnected, once it reopens: the client user connected
    /// meanwhile, or a guest when there is no session.
    func resumeAfterCommunityReopening() {
        // The session kept through the closure is still the user's. Without one (a first launch on the closed
        // community, a disconnect meanwhile), or with a client user connected meanwhile, connect now.
        guard let userData = userDataStorage.userData else {
            connectAsync()
            return
        }
        if let clientUserData = userDataStorage.clientUserData, userData.clientId != clientUserData.id {
            connectAsync()
        }
    }

    private func connect() async throws(ConnectionError) {
        // No call while the community is closed: `resumeAfterCommunityReopening()` connects once it reopens.
        guard !closureRepository.isClosed else { return }
        guard beginConnecting() else { return }
        do {
            if let clientUserData = userDataStorage.clientUserData {
                do throws(ExchangeTokenError) {
                    try await connectWithClientUser(clientUserId: clientUserData.id)
                } catch {
                    if #available(iOS 14, *) { Logger.connection.debug("Error while connecting with client user: \(error)") }
                    // The exchange can go through before the failure, which then comes from the update of the
                    // profile: the user has their own session.
                    let clientSessionIsStored = userDataStorage.userData?.clientId == clientUserData.id
                    // With their migrated profile, the profile repository sends the update again once the
                    // community opens to the user: connecting them again then would only race it. Without it (the
                    // exchange failed, or the migration of their profile did), they are connected again then. The
                    // refusal tells it too: the access read on the previous launch can still say it is open.
                    let accessIsRefused = if case .communityAccessDenied = error { true } else { false }
                    if configRepository.userConfig?.canAccessCommunity == false || accessIsRefused,
                       !exchangeStoredMigratedProfile {
                        isWaitingForCommunityAccessToConnectClient = true
                    }
                    // Falling back to a guest keeps the community browsable when the exchange fails for a
                    // passing reason. A ban is not one: it is the server's answer about this very user,
                    // and handing them a fresh guest identity instead both answers a refusal with a way
                    // around it and drops the only explanation there was — leaving the UI with nothing
                    // better to offer than trying again in a few moments, which is exactly what a banned
                    // user cannot do. Let the ban travel up instead, all the way to the host's
                    // `connectUser`, as it does on Android.
                    // Nor when the user has their own session: a guest would replace it with a new account, one
                    // more on each launch.
                    if case .notConnected = connectionState, !isBan(error), !clientSessionIsStored {
                        try await connectAsGuest()
                    } else {
                        throw error
                    }
                }
            } else {
                try await connectAsGuest()
            }
        } catch {
            let connectionError: ConnectionError
            if let error = error as? ConnectionError {
                connectionError = error
            } else if let error = error as? ExchangeTokenError {
                connectionError = .init(from: error)
            } else {
                connectionError = .unknown(error)
            }
            record(connectionError)
            connectionStateIsSet = true
            isConnecting = false
            throw connectionError
        }
        // The connection can store the very session and profile the failed one left, as when the profile that
        // could not be migrated was stored as the migration leaves it: the state then sees nothing change, and
        // would keep the error.
        stateLock.withLock {
            if case let .connected(user, error) = self.connectionState, error != nil,
               user.jwtToken == self.userDataStorage.userData?.jwtToken {
                self.connectionState = .connected(user, nil)
            }
        }
        isConnecting = false
    }

    /// Takes the connection for the caller, and forgets the error of the previous one.
    /// - Returns: `false` when a connection is already running: checking and taking are one step, so that two
    ///   callers cannot both take it.
    private func beginConnecting() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard !isConnecting else { return false }
        isConnecting = true
        lastConnectionError = nil
        return true
    }

    /// Whether the connected user is a guest whose session is still the stored one. The exchange of the client
    /// token replaces the guest's session before the state shows the client user's account, which takes a few hops
    /// of the main queue, or never when their profile cannot be stored. Told by the kind of the stored session, a
    /// client user's carrying their id, not by its token, which a renewal replaces ahead of the state too.
    private func isGuestSession(_ user: User) -> Bool {
        user.profile.isGuest && userDataStorage.userData?.clientId == nil
    }

    /// Whether a failed client-user exchange was the server refusing a banned user, as opposed to the
    /// passing failures (no network, server hiccup) a guest session is a reasonable answer to.
    private func isBan(_ error: Error) -> Bool {
        guard let exchangeTokenError = error as? ExchangeTokenError,
              case let .detailedErrors(errors) = exchangeTokenError else { return false }
        return errors.contains { $0.reason == .userBanned }
    }

    private func connectAsGuest() async throws(ConnectionError) {
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        do {
            let response = try await remoteClient.userService.getGuestJwt()

            switch response.result {
            case let .success(connectionData):
                let profile = StorableCurrentUserProfile(from: connectionData.profile, userId: connectionData.userID)
                try await userProfileDatabase.upsert(profile: profile)
                userDataStorage.store(userData: .init(id: connectionData.userID, jwtToken: connectionData.jwt))
            case let .fail(failure):
                let detailedErrors = failure.errors.map { ConnectionError.DetailedError(from: $0) }
                throw ConnectionError.detailedErrors(detailedErrors)
            case .none:
                // this will happen only if we add new values to the `result`.
                // Since they are not supported in this version, throw an error
                throw InternalError.invalidArgument
            }
        } catch {
            if let connectionError = error as? ConnectionError {
                throw connectionError
            } else if let error = error as? RemoteClientError {
                throw .server(ServerError(remoteClientError: error))
            } else {
                throw .unknown(error)
            }
        }
    }

    /// The message of the ban when the access read with the token just stored says the account is banned, `nil`
    /// otherwise.
    ///
    /// The server lets the exchange of a banned account go through, with a token that only reads the access: the
    /// ban, which used to be the failure of the exchange, is now told by the access. Read here, the host app keeps
    /// being told about it by the call that exchanged the token. A read that fails tells nothing: the connection
    /// goes on, and the next read of the access catches the ban.
    private func banMessageAfterExchange() async -> String? {
        let userConfig = try? await configRepository.refreshCommunityAccess()
        return userConfig?.banMessage
    }

    /// - Parameter authenticated: whether the exchange is sent with the token of the current session when there is
    ///   one. `false` when that session is the one of a deleted account, which must not be joined to the new one.
    private func connectWithClientUser(clientUserId: String, authenticated: Bool = true)
    async throws(ExchangeTokenError) {
        exchangeStoredMigratedProfile = false
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        // a client user with a callback to get token should have been set prior to this call
        guard let clientUserTokenProvider else { throw .unknown(InternalError.incorrectState) }
        // avoid the user profile fetch monitor to fetch the profile until all actions on the profile are done
        userProfileFetchMonitor.set(connectionInProgress: true)
        defer { userProfileFetchMonitor.set(connectionInProgress: false) }
        do {
            if #available(iOS 14, *) { Logger.connection.trace("Asking for client user token") }
            let token = try await clientUserTokenProvider()
            if #available(iOS 14, *) { Logger.connection.trace("Exchanging client user token for Octopus JWT") }
            let response = try await remoteClient.userService.getJwt(
                clientToken: token,
                authenticationMethod: authenticated
                    ? authenticatedCallProvider.authenticatedIfPossibleMethod() : .notAuthenticated)
            switch response.result {
            case let .success(connectionData):
                // do it before setting the profile because we might need the token in updateProfileWithClientUser
                userDataStorage.store(userData: .init(id: connectionData.userID, clientId: clientUserId, jwtToken: connectionData.jwt))

                // Before the profile is migrated or updated: neither is sent for a banned account.
                if let banMessage = await banMessageAfterExchange() {
                    throw ExchangeTokenError.detailedErrors([.init(reason: .userBanned, message: banMessage)])
                }

                // Migrate if needed. When it fails, the user still has their account, as on Android: their profile
                // is stored as the migration would leave it, so that the state is theirs rather than the guest's
                // they may have had, whose session the exchange replaced. The next exchange migrates it: the next
                // connectUser, also on a later launch, or the one once the community opens to the user.
                let frictionlessProfile: StorableCurrentUserProfile
                do {
                    frictionlessProfile = try await frictionlessProfileMigrator.migrateUserToFrictionlessUserIfNeeded(
                        profile: connectionData.profile, userId: connectionData.userID)
                } catch {
                    try? await userProfileDatabase.upsert(profile: frictionlessProfileMigrator.profileAsMigrated(
                        connectionData.profile, userId: connectionData.userID))
                    throw error
                }
                var profileFilledWithClientUserInfo: StorableCurrentUserProfile?
                if let clientUserProfile = try? await clientUserProfileDatabase.getProfile(clientUserId: clientUserId) {
                    let clientUser = ClientUser(userId: clientUserId, profile: clientUserProfile)
                    do {
                        profileFilledWithClientUserInfo = try await clientUserProfileMerger
                            .updateProfileWithClientUser(clientUser, profile: frictionlessProfile,
                                                         userId: connectionData.userID)
                    } catch {
                        // The user has their account even when the profile cannot be filled with the client
                        // user's info, as the server refuses it to a user who cannot access the community.
                        // Android saves the session before the update too. Stored only now: a profile stored
                        // while the update is in flight would have the profile repository send it a second time.
                        if (try? await userProfileDatabase.upsert(profile: frictionlessProfile)) != nil {
                            exchangeStoredMigratedProfile = true
                        }
                        throw error
                    }
                }
                try await userProfileDatabase.upsert(profile: profileFilledWithClientUserInfo ?? frictionlessProfile)
                exchangeStoredMigratedProfile = true
            case let .fail(failure):
                let detailedErrors = failure.errors.map { ExchangeTokenError.DetailedError(from: $0) }
                throw ExchangeTokenError.detailedErrors(detailedErrors)
            case .none:
                // this will happen only if we add new values to the `result`. Since they are not supported in this version, throw an error
                throw InternalError.invalidArgument
            }
        } catch {
            if let exchangeTokenError = error as? ExchangeTokenError {
                throw exchangeTokenError
            } else if let error = error as? UpdateProfile.Error {
                // The server refuses the update to a user who cannot access the community. Not narrowed down with
                // the user config: on a first connection, it can still be the guest's, or not loaded yet.
                if case .serverCall(.serverError(.permissionDenied)) = error {
                    throw .communityAccessDenied
                }
                throw .profileUpdateError(error)
            } else if let error = error as? RemoteClientError {
                if case let .unknown(underlyingError) = error,
                   let grpcError = underlyingError as? GRPCStatus,
                   let message = grpcError.message, message.contains("Invalid JWT token") {
                    throw .jwtError
                }
                throw .server(ServerError(remoteClientError: error))
            } else {
                throw .unknown(error)
            }
        }
    }

    func onAuthenticatedCallFailed() async throws {
        // Preserve the guest identity on a hard auth failure: a guest must never be destroyed and
        // re-forged, as the server gives each new guest session a new user id (that inflated iOS user_id
        // counts ~7x vs Android). The guest session is kept as-is. Only a logged-in client user is logged out.
        if case let .connected(user, _) = connectionState, isGuestSession(user) {
            return
        }
        try await logout()
        guard !isLoggingOutAfterUnauthenticatedError else { return }
        isLoggingOutAfterUnauthenticatedError = true
        defer { isLoggingOutAfterUnauthenticatedError = false }
        // Wait to be in the correct state to try to re-connect the user
        try? await TaskUtils.wait(for: {
            if case .notConnected = connectionState { return true }
            return false
        }())
        try await connect()
    }

    func reconnectAfterAccountDeletion() async throws(ConnectionError) {
        try await replaceSession(.accountDeleted)
    }

    /// Why a session is replaced.
    private enum SessionEnd {
        /// The member whose account was deleted asks to come back: the session is the current one, replaced once a
        /// read of the access still says so.
        case accountDeleted
        /// A read of the access found this session over.
        case sessionEnded(UserDataStorage.UserData?)
    }

    /// Keeps a member's ended session for `connectUser` when the app has not given the token provider yet in this
    /// launch: without it, the replacement would be a guest, and `connectUser` would exchange again right after.
    /// - Returns: whether the session is left to `connectUser`.
    private func leaveToConnectUser(_ endedSession: UserDataStorage.UserData?) -> Bool {
        replacementLock.lock()
        defer { replacementLock.unlock() }
        guard endedSession?.clientId != nil, clientUserTokenProvider == nil else { return false }
        endedSessionAwaitingClient = endedSession
        return true
    }

    /// Sets the token provider `connectUser` was given, and takes the ended session left for it, if any.
    private func setTokenProvider(_ tokenProvider: @escaping () async throws -> String)
    -> UserDataStorage.UserData? {
        replacementLock.lock()
        defer { replacementLock.unlock() }
        clientUserTokenProvider = tokenProvider
        defer { endedSessionAwaitingClient = nil }
        return endedSessionAwaitingClient
    }

    /// Whether a session the server ended can be replaced now, which then counts as its replacement: at most one
    /// every `minIntervalBetweenEndedSessionReplacements`. Called on the main queue.
    private func takeEndedSessionReplacementTurn() -> Bool {
        let now = Date()
        // A clock set back must not hold the replacements for longer than the interval.
        if let last = lastEndedSessionReplacementDate, now >= last,
           now.timeIntervalSince(last) < minIntervalBetweenEndedSessionReplacements {
            return false
        }
        lastEndedSessionReplacementDate = now
        return true
    }

    /// Gets a new session in place of one that is over: a new account when the client user and their token provider
    /// are known, a guest otherwise. The session is only replaced once the new one is obtained: when this throws,
    /// nothing changed and it can be asked again.
    private func replaceSession(_ end: SessionEnd) async throws(ConnectionError) {
        // No call while the community is closed, and nothing to try without network: the session is left as it is.
        guard !closureRepository.isClosed else { return }
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        guard beginSessionReplacement() else {
            // The replacement already running answers this one too.
            try? await TaskUtils.wait(for: !isReplacementRunning, timeout: 30)
            return
        }
        defer { endSessionReplacement() }
        let endedSession: UserDataStorage.UserData?
        switch end {
        case .accountDeleted: endedSession = userDataStorage.userData
        case let .sessionEnded(session): endedSession = session
        }
        // Waits for the connection running, if any, then takes it: another caller can take it in between.
        repeat {
            do {
                try await TaskUtils.wait(for: !isConnecting, timeout: 3)
            } catch {
                throw .unknown(error)
            }
        } while !beginConnecting()
        defer { isConnecting = false }
        // A connection that ended meanwhile, or a previous replacement, may have left that session already.
        guard isSession(of: endedSession) else { return }
        if case .accountDeleted = end {
            // Read again first: the stored reason can be late, and a tap can come from a screen about to leave. A
            // session that has its access must not be replaced. When the read fails, the stored reason is all there
            // is. An ended session was just read as such: it is not stored, nothing could be late.
            let access = (try? await configRepository.refreshCommunityAccess()) ?? configRepository.userConfig
            guard access?.noAccessReason == .accountDeleted else { return }
        }
        // The state can be late on the session: the profile it shows is only the ended session's when their user ids
        // match.
        let endedProfileId = connectionState.user.flatMap {
            $0.profile.userId == endedSession?.id ? $0.profile.id : nil
        }

        var readAccess = false
        if let clientUserData = userDataStorage.clientUserData, clientUserTokenProvider != nil {
            do {
                // Without the token of the ended session: the server gives the client user a new account.
                try await connectWithClientUser(clientUserId: clientUserData.id, authenticated: false)
                readAccess = true
            } catch {
                let connectionError = ConnectionError(from: error)
                let sessionReplaced = !isSession(of: endedSession)
                if isBan(error) {
                    // As a connection does: the ban goes up, and no guest stands in for a banned member.
                    if sessionReplaced {
                        await deleteProfile(ofUserId: endedSession?.id, profileId: endedProfileId)
                    }
                    record(connectionError)
                    throw connectionError
                }
                if sessionReplaced {
                    // The exchange gave the new account, what followed it failed: the member is back all the same.
                    record(connectionError)
                    readAccess = true
                }
                // otherwise a passing failure of the exchange: a guest session, as a connection falls back to
            }
        }
        if isSession(of: endedSession) {
            // The exchange gave back the account the member already had: it is not over, the stored reason was late
            // (a previous replacement whose read of the access failed). It is theirs to keep, with its profile.
            guard !readAccess else { return }
            // Throws when no guest session can be had either: nothing changed, the replacement can be asked again.
            try await connectAsGuest()
        }
        await deleteProfile(ofUserId: endedSession?.id, profileId: endedProfileId)
        if !readAccess {
            // The exchange reads the access itself. For a guest, read here: the screen leaves once it is granted.
            _ = try? await configRepository.refreshCommunityAccess()
        }
    }

    /// Whether the stored session is still the one of `session`'s account. Told by its ids, not by its token,
    /// which any call can renew.
    private func isSession(of session: UserDataStorage.UserData?) -> Bool {
        let current = userDataStorage.userData
        return current?.id == session?.id && current?.clientId == session?.clientId
    }

    private var isReplacementRunning: Bool {
        replacementLock.lock()
        defer { replacementLock.unlock() }
        return isReplacingSession
    }

    /// - Returns: `false` when a replacement is already running.
    private func beginSessionReplacement() -> Bool {
        replacementLock.lock()
        defer { replacementLock.unlock() }
        guard !isReplacingSession else { return false }
        isReplacingSession = true
        return true
    }

    private func endSessionReplacement() {
        replacementLock.lock()
        defer { replacementLock.unlock() }
        isReplacingSession = false
    }

    /// Deletes the profile of an account whose session was replaced, as a logout does.
    private func deleteProfile(ofUserId userId: String?, profileId: String?) async {
        if let profileId {
            try? await profileRepository.deleteCurrentUserProfile(profileId: profileId)
        }
        if let userId, userId != userDataStorage.userData?.id {
            try? await userProfileDatabase.delete(userId: userId)
        }
    }

    func linkClientUserToOctopusUser() async throws(ExchangeTokenError) {
        do {
            try await connect()
        } catch {
            throw ExchangeTokenError(from: error)
        }
    }

    func refreshEntitlements() async throws(RefreshEntitlementsCoreError) {
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        guard let user = connectionState.user, !user.profile.isGuest else {
            throw .notConnected
        }
        guard let clientUserTokenProvider else { throw .noClientTokenProvider }
        guard let clientUserId = userDataStorage.clientUserData?.id else { throw .notConnected }
        do {
            let clientToken = try await clientUserTokenProvider()
            let response = try await remoteClient.userService.getJwt(
                clientToken: clientToken,
                authenticationMethod: authenticatedCallProvider.authenticatedIfPossibleMethod()
            )
            switch response.result {
            case let .success(connectionData):
                userDataStorage.store(userData: .init(
                    id: connectionData.userID,
                    clientId: clientUserId,
                    jwtToken: connectionData.jwt
                ))
                if let banMessage = await banMessageAfterExchange() {
                    throw RefreshEntitlementsCoreError.userBanned(banMessage)
                }
                let frictionlessProfile = try await frictionlessProfileMigrator
                    .migrateUserToFrictionlessUserIfNeeded(
                        profile: connectionData.profile,
                        userId: connectionData.userID
                    )
                try await userProfileDatabase.upsert(profile: frictionlessProfile)
            case let .fail(failure):
                let detailedErrors = failure.errors.map { ExchangeTokenError.DetailedError(from: $0) }
                if let banned = detailedErrors.first(where: { $0.reason == .userBanned }) {
                    throw RefreshEntitlementsCoreError.userBanned(banned.message)
                }
                throw RefreshEntitlementsCoreError.serverError(
                    RefreshEntitlementsServerError(messages: detailedErrors.map(\.message))
                )
            case .none:
                throw RefreshEntitlementsCoreError.serverError(InternalError.invalidArgument)
            }
        } catch let error as RefreshEntitlementsCoreError {
            throw error
        } catch let error as RemoteClientError {
            throw .serverError(error)
        } catch {
            throw .serverError(error)
        }
    }
}

private class SyncResultHolder: @unchecked Sendable {
    var result: Result<Void, UpdateProfile.Error>?
}
