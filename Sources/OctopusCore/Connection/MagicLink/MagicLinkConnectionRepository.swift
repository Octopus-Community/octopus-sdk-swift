//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import OctopusRemoteClient
import OctopusDependencyInjection
import OctopusGrpcModels

class MagicLinkConnectionRepository: ConnectionRepository, InjectableObject, @unchecked Sendable {
    public static let injectedIdentifier = Injected.connectionRepository

    public var connectionStatePublisher: AnyPublisher<ConnectionState, Never> {
        $connectionState.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
    @Published private(set) public var connectionState = ConnectionState.notConnected(nil)

    public var magicLinkRequestPublisher: AnyPublisher<MagicLinkRequest?, Never> {
        $magicLinkRequest.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
    @Published private(set) public var magicLinkRequest: MagicLinkRequest?

    public let clientUserConnected = false

    public let connectionMode: ConnectionMode
    private let profileRepository: ProfileRepository
    private let userDataStorage: UserDataStorage
    private let remoteClient: OctopusRemoteClient
    private let networkMonitor: NetworkMonitor
    private let userProfileDatabase: CurrentUserProfileDatabase
    private let magicLinkMonitor: MagicLinkMonitor
    private let authCallProvider: AuthenticatedCallProvider
    private var userInDbCancellable: AnyCancellable?

    private var storage: Set<AnyCancellable> = []
    private var connectionStateIsSet = false
    @Published private var isConnecting = false
    @Published private var clientIsConnecting = false
    private var isLoggingOutAfterUnauthenticatedError = false

    private var clientUserTokenProvider: (() async throws -> String)?

    init(connectionMode: ConnectionMode, injector: Injector) {
        self.connectionMode = connectionMode
        profileRepository = injector.getInjected(identifiedBy: Injected.profileRepository)
        userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        networkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor)
        userProfileDatabase = injector.getInjected(identifiedBy: Injected.currentUserProfileDatabase)
        magicLinkMonitor = injector.getInjected(identifiedBy: Injected.magicLinkMonitor)
        authCallProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)

        Publishers.CombineLatest(
            userDataStorage.$userData.removeDuplicates().receive(on: DispatchQueue.main),
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
        .sink { [weak self] userData, profile in
            guard let self else { return }
            if let profile, let userData {
                connectionState = .connected(User(profile: profile, jwtToken: userData.jwtToken), nil)
                connectionStateIsSet = true
            }
        }
        .store(in: &storage)

        Publishers.CombineLatest(
            userDataStorage.$userData.removeDuplicates().receive(on: DispatchQueue.main),
            // ensure that profile value is not the initial one
            Publishers.CombineLatest(
                profileRepository.profilePublisher,
                profileRepository.hasLoadedProfilePublisher.filter { $0 }
            ).map { $0.0 }.removeDuplicates().receive(on: DispatchQueue.main)
        )
        .first()
        .sink { [unowned self] userData, profile in
            if profile == nil && userData == nil {
                connectAsync()
            }
        }
        .store(in: &storage)

        userDataStorage.$magicLinkData
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] magicLinkData in
                magicLinkRequest = magicLinkData.map { MagicLinkRequest(email: $0.email, error: nil) }
            }.store(in: &storage)

        magicLinkMonitor
            .magicLinkAuthenticationResponsePublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] response in
                // can ignore error that are threw because the connection state is also changed
                _ = try? processMagicLinkConfirmation(response)
            }
            .store(in: &storage)
    }

    public func sendMagicLink(to email: String) async throws(MagicLinkEmailEntryError) {
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        do {
            guard case let .octopus(deepLink) = connectionMode else { throw InternalError.wrongConnectionMode }
            let response = try await remoteClient.magicLinkService.generateLink(email: email, deepLink: deepLink)
            switch response.result {
            case let .magicLinkID(magicLinkId):
                userDataStorage.store(magicLinkData: .init(magicLinkId: magicLinkId, email: email))
            case let .error(error):
                throw MagicLinkEmailEntryError.detailedError(.init(from: error))
            case .none:
                throw MagicLinkEmailEntryError.unknown(nil)
            }
        } catch {
            if let magicLinkError = error as? MagicLinkEmailEntryError {
                throw magicLinkError
            } else if let error = error as? RemoteClientError {
                throw .server(ServerError(remoteClientError: error))
            } else {
                throw .unknown(error)
            }
        }
    }

    public func cancelMagicLink() {
        guard case .octopus = connectionMode else { return }
        userDataStorage.store(magicLinkData: nil)
    }

    public func checkMagicLinkConfirmed() async throws(MagicLinkConfirmationError) -> Bool {
        guard let magicLinkData = userDataStorage.magicLinkData else {
            throw .noMagicLink
        }
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        do {
            let response = try await remoteClient.magicLinkService.getJwt(
                magicLinkId: magicLinkData.magicLinkId, email: magicLinkData.email)
            return try processMagicLinkConfirmation(response)
        } catch {
            if let magicLinkError = error as? MagicLinkConfirmationError {
                throw magicLinkError
            }
            throw .unknown(error)
        }
    }

    public func logout() async throws {
        let profileId: String? = if case let .connected(user, _) = connectionState {
            user.profile.id
        } else { nil }
        userDataStorage.store(userData: nil)
        if let profileId {
            try await profileRepository.deleteCurrentUserProfile(profileId: profileId)
        }
        await connect()
    }

    public func deleteAccount(reason: DeleteAccountReason) async throws(AuthenticatedActionError) {
        guard case let .connected(user, _) = connectionState else { throw .userNotAuthenticated }
        do {
            guard case .octopus = connectionMode else { throw InternalError.wrongConnectionMode }
            _ = try await remoteClient.userService.deleteAccount(
                userId: user.profile.userId,
                reason: reason.protoValue,
                authenticationMethod: try authCallProvider.authenticatedMethod())
            try await logout()
        } catch {
            if let error = error as? AuthenticatedActionError {
                throw error
            } else if let error = error as? RemoteClientError {
                throw .serverError(ServerError(remoteClientError: error))
            } else {
                throw .other(error)
            }
        }
    }

    private func connectAsync() {
        Task {
            // since guest connection might be currently happening, wait for it to end
            try? await TaskUtils.wait(for: !isConnecting)
            await connect()

        }
    }

    private func connect() async {
        guard !isConnecting else { return }
        isConnecting = true
        do {
            try await connectAsGuest()
        } catch {
            switch connectionState {
            case .notConnected:
                connectionState = .notConnected(error)
            case let .connected(user, _):
                connectionState = .connected(user, error)
            }
            connectionStateIsSet = true
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
                // this will happen only if we add new values to the `result`. Since they are not supported in this version, throw an error
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

    @discardableResult
    private func processMagicLinkConfirmation(
        _ response: Com_Octopuscommunity_IsAuthenticatedResponse) throws(MagicLinkConfirmationError) -> Bool {
            guard let magicLinkRequest else { return false }
            switch response.result {
            case .success(let success):
                let profile = StorableCurrentUserProfile(from: success.profile, userId: success.userID)
                Task {
                    try await userProfileDatabase.upsert(profile: profile)
                    // wait for the db to be sure to have all information about the profile in the db to avoid
                    // a race condition where the user data is here but not yet the profile.
                    // In this case, the create profile is displayed and at the next run loop since the profile is
                    // here, the screen is popped and the magic link screen is displayed
                    userInDbCancellable = userProfileDatabase.profilePublisher(userId: success.userID)
                        .replaceError(with: nil)
                        .first { $0 != nil }
                        .receive(on: DispatchQueue.main)
                        .sink { [unowned self] result in
                            userDataStorage.store(userData: .init(id: success.userID, jwtToken: success.jwt))
                            userDataStorage.store(magicLinkData: nil)
                            userInDbCancellable = nil
                        }
                }
                return true
            case .error(let error):
                switch error.errorCode {
                case .notAuthenticatedYet:
                    return false
                case .expiredLink:
                    let error = MagicLinkConfirmationError.magicLinkExpired
                    self.magicLinkRequest = MagicLinkRequest(email: magicLinkRequest.email, error: error)
                    throw error
                case .linkNotFound, .userNotFound, .invalidLink:
                    let error = MagicLinkConfirmationError.needNewMagicLink
                    self.magicLinkRequest = MagicLinkRequest(email: magicLinkRequest.email, error: error)
                    throw error
                case .userBanned:
                    let error = MagicLinkConfirmationError.userBanned(error.message)
                    self.magicLinkRequest = MagicLinkRequest(email: magicLinkRequest.email, error: error)
                    throw error
                case .unknownError, .UNRECOGNIZED(_):
                    let error = MagicLinkConfirmationError.unknown(nil)
                    self.magicLinkRequest = MagicLinkRequest(email: magicLinkRequest.email, error: error)
                    throw error
                }
            case .none:
                let error = MagicLinkConfirmationError.unknown(nil)
                self.magicLinkRequest = MagicLinkRequest(email: magicLinkRequest.email, error: error)
                throw error
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
        await connect()
    }

    func connectUser(_ user: ClientUser, tokenProvider: @escaping () async throws -> String) async throws {
        preconditionFailure("Dev error: the sdk is not configured to handle SSO")
    }

    func disconnectUser() async throws {
        preconditionFailure("Dev error: the sdk is not configured to handle SSO")
    }

    func linkClientUserToOctopusUser() async throws(ExchangeTokenError) {
        preconditionFailure("Dev error: the sdk is not configured to handle SSO")
    }
}
