//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import os
import OctopusRemoteClient
import OctopusDependencyInjection
import OctopusGrpcModels

class SSOConnectionRepository: ConnectionRepository, InjectableObject, @unchecked Sendable {
    public static let injectedIdentifier = Injected.connectionRepository

    public var connectionStatePublisher: AnyPublisher<ConnectionState, Never> {
        $connectionState.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
    @Published private(set) public var connectionState: ConnectionState = .notConnected(nil)

    public var magicLinkRequestPublisher: AnyPublisher<MagicLinkRequest?, Never> { Just(nil).eraseToAnyPublisher() }
    public let magicLinkRequest: MagicLinkRequest? = nil
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
            userDataStorage.$userData.map { $0 == nil }.removeDuplicates().receive(on: DispatchQueue.main),
            // ensure that profile value is not the initial one
            Publishers.CombineLatest(
                profileRepository.profilePublisher,
                profileRepository.hasLoadedProfilePublisher.filter { $0 }
            ).map { $0.0 == nil }.removeDuplicates().receive(on: DispatchQueue.main),
            networkMonitor.connectionAvailablePublisher.filter { $0 }
        )
        .first()
        .sink { [unowned self] userDataIsNil, profileIsNil, _ in
            if profileIsNil && userDataIsNil {
                connectAsync()
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
            connectAsync()
        }
    }

    func disconnectUser() async throws {
        guard userDataStorage.clientUserData != nil else { return }
        clientIsConnecting = true
        defer { clientIsConnecting = false }
        try await logout()
        connectAsync()
    }

    func logout() async throws {
        let profileId: String? = if case let .connected(user, _) = connectionState {
            user.profile.id
        } else { nil }
        let previousClientUserId = userDataStorage.clientUserData?.id
        self.clientUserTokenProvider = nil
        userDataStorage.store(clientUserData: nil)
        userDataStorage.store(userData: nil)
        if let previousClientUserId {
            try await clientUserProfileDatabase.delete(clientUserId: previousClientUserId)
        }
        if let profileId {
            try await profileRepository.deleteCurrentUserProfile(profileId: profileId)
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
                    if case .notConnected = connectionState {
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
            } else if let error = error as? RemoteClientError {
                throw .server(ServerError(remoteClientError: error))
            } else {
                throw .unknown(error)
            }
        }
    }

    func onAuthenticatedCallFailed() async throws {
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

    func sendMagicLink(to email: String) async throws(MagicLinkEmailEntryError) {
        preconditionFailure("Dev error: the sdk is not configured to handle Octopus connection")
    }

    public func cancelMagicLink() {
        preconditionFailure("Dev error: the sdk is not configured to handle Octopus connection")
    }

    public func checkMagicLinkConfirmed() async throws(MagicLinkConfirmationError) -> Bool {
        preconditionFailure("Dev error: the sdk is not configured to handle Octopus connection")
    }

    public func deleteAccount(reason: DeleteAccountReason) async throws(AuthenticatedActionError) {
        preconditionFailure("Dev error: the sdk is not configured to handle Octopus connection")
    }
}
