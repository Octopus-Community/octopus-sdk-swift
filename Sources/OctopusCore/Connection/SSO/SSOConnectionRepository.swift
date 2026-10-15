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
    private let userProfileFetchMonitor: UserProfileFetchMonitor
    private let clientUserProfileMerger: ClientUserProfileMerger
    private let frictionlessProfileMigrator: FrictionlessProfileMigrator

    private var storage: Set<AnyCancellable> = []
    private var connectionStateIsSet = false
    @Published private var isConnecting = false
    @Published private var clientIsConnecting = false
    private var isLoggingOutAfterUnauthenticatedError = false
    private var lastConnectionError: Error?

    @Published private var isWaitingForCommunityAccessToConnectClient = false

    private var clientUserTokenProvider: (() async throws -> String)?

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
                connectionState = .connected(User(profile: profile, jwtToken: userData.jwtToken), lastConnectionError)
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

        // When community access is disabled, exchanging the client token for an Octopus one won't work.
        // Hence, wait for the community access to be enabled to connect the client user.
        $isWaitingForCommunityAccessToConnectClient
            .map { [unowned self] in
                guard $0 else {
                    return Empty<Void, Never>().eraseToAnyPublisher()
                }

                return configRepository.userConfigPublisher
                    .filter { $0?.canAccessCommunity ?? false }
                    .removeDuplicates()
                    .map { _ in }
                    .eraseToAnyPublisher()
            }
            .switchToLatest()
            .sink { [unowned self] in
                isWaitingForCommunityAccessToConnectClient = false
                connectAsync()
            }.store(in: &storage)
    }

    func connectUser(_ user: ClientUser, tokenProvider: @escaping () async throws -> String) async throws {
        clientIsConnecting = true
        defer { clientIsConnecting = false }
        try await waitForReadableSession()
        let previousClientUserId = userDataStorage.clientUserData?.id
        // since connection state is not set immediatly, we need to wait for its first "real" value, not the one that
        // it has been init with.
        try? await TaskUtils.wait(for: connectionStateIsSet, timeout: 4)
        let currentState = connectionState
        // if client user changed, logout
        if let previousClientUserId, previousClientUserId != user.userId {
            try await logout()
            try await clientUserProfileDatabase.delete(clientUserId: previousClientUserId)
        }
        self.clientUserTokenProvider = tokenProvider

        // Check if client profile changed before the upsert (for the else branch)
        let existingClientProfile = try? await clientUserProfileDatabase.getProfile(clientUserId: user.userId)

        // Subscribe before the upsert that triggers the Combine-based profile sync
        let syncResultHolder = SyncResultHolder()
        let syncCancellable = profileRepository.profileSyncResultPublisher
            .first()
            .sink { [syncResultHolder] in syncResultHolder.result = $0 }

        try await clientUserProfileDatabase.upsert(profile: user.profile, clientUserId: user.userId)
        // if state is not connected to the same user, ask for a token
        let tokenNeeded: Bool
        switch currentState {
        case let .connected(currentUser, error):
            tokenNeeded = previousClientUserId != user.userId || currentUser.profile.isGuest || error != nil
        default:
            tokenNeeded = true
        }
        if previousClientUserId != user.userId {
            userDataStorage.store(clientUserData: .init(id: user.userId))
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
            guard configRepository.userConfig?.canAccessCommunity ?? false else {
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
        let guestUser: User? = if case let .connected(user, _) = state, user.profile.isGuest { user } else { nil }
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
            lastConnectionError = nil
            connectionState = .connected(guestUser, nil)
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

    private func connect() async throws(ConnectionError) {
        guard !isConnecting else { return }
        isConnecting = true
        lastConnectionError = nil
        do {
            if let clientUserData = userDataStorage.clientUserData {
                do {
                    try await connectWithClientUser(clientUserId: clientUserData.id)
                } catch {
                    if #available(iOS 14, *) { Logger.connection.debug("Error while connecting with client user: \(error)") }
                    if configRepository.userConfig?.canAccessCommunity == false {
                        isWaitingForCommunityAccessToConnectClient = true
                    }
                    // Falling back to a guest keeps the community browsable when the exchange fails for a
                    // passing reason. A ban is not one: it is the server's answer about this very user,
                    // and handing them a fresh guest identity instead both answers a refusal with a way
                    // around it and drops the only explanation there was — leaving the UI with nothing
                    // better to offer than trying again in a few moments, which is exactly what a banned
                    // user cannot do. Let the ban travel up instead, all the way to the host's
                    // `connectUser`, as it does on Android.
                    if case .notConnected = connectionState, !isBan(error) {
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
            switch connectionState {
            case .notConnected:
                connectionState = .notConnected(connectionError)
            case let .connected(user, _):
                connectionState = .connected(user, connectionError)
            }
            lastConnectionError = connectionError
            connectionStateIsSet = true
            isConnecting = false
            throw connectionError
        }
        isConnecting = false
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

    private func connectWithClientUser(clientUserId: String) async throws(ExchangeTokenError) {
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
                authenticationMethod: authenticatedCallProvider.authenticatedIfPossibleMethod())
            switch response.result {
            case let .success(connectionData):
                // do it before setting the profile because we might need the token in updateProfileWithClientUser
                userDataStorage.store(userData: .init(id: connectionData.userID, clientId: clientUserId, jwtToken: connectionData.jwt))

                // migrate if needed
                let frictionlessProfile = try await frictionlessProfileMigrator.migrateUserToFrictionlessUserIfNeeded(
                    profile: connectionData.profile, userId: connectionData.userID)

                var profileFilledWithClientUserInfo: StorableCurrentUserProfile?
                if let clientUserProfile = try? await clientUserProfileDatabase.getProfile(clientUserId: clientUserId) {
                    let clientUser = ClientUser(userId: clientUserId, profile: clientUserProfile)
                    profileFilledWithClientUserInfo = try await clientUserProfileMerger.updateProfileWithClientUser(
                        clientUser, profile: frictionlessProfile, userId: connectionData.userID)
                }
                try await userProfileDatabase.upsert(profile: profileFilledWithClientUserInfo ?? frictionlessProfile)
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
                if case let .serverCall(authenticatedActionError) = error,
                   case let .serverError(serverError) = authenticatedActionError,
                   case let .unknown(underlyingError) = serverError,
                   let grpcError = underlyingError as? GRPCStatus,
                   grpcError.code == .permissionDenied {
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
        // re-forged (that inflated iOS user_id counts ~7x vs Android). The stable per-device guest
        // (installId-based) is kept as-is. Only a logged-in client user is logged out.
        if case let .connected(user, _) = connectionState, user.profile.isGuest {
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
