//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import RemoteClient
import DependencyInjection
import GrpcModels

class SSOConnectionRepository: ConnectionRepository, InjectableObject, @unchecked Sendable {
    public static let injectedIdentifier = Injected.connectionRepository

    public var connectionStatePublisher: AnyPublisher<ConnectionState, Never> {
        $connectionState.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
    @Published private(set) public var connectionState = ConnectionState.notConnected

    public let connectionMode: ConnectionMode
    private let remoteClient: RemoteClient
    private let userDataStorage: UserDataStorage
    private let authCallProvider: AuthenticatedCallProvider
    private let networkMonitor: NetworkMonitor
    private let ssoExchangeTokenMonitor: SSOExchangeTokenMonitor
    private let profileRepository: ProfileRepository
    private let userProfileDatabase: CurrentUserProfileDatabase
    private let clientUserProfileDatabase: ClientUserProfileDatabase
    private let postFeedsStore: PostFeedsStore
    private let clientUserProvider: ClientUserProvider
    private var storage: Set<AnyCancellable> = []
    private var userInDbCancellable: AnyCancellable?

    private var receivedProfile: CurrentUserProfile?
    private var latestDisconnectionReason: String?

    private var clientUserTokenProvider: (() async throws -> String)?

    init(connectionMode: ConnectionMode, injector: Injector) {
        self.connectionMode = connectionMode
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        authCallProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)
        networkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor)
        ssoExchangeTokenMonitor = injector.getInjected(identifiedBy: Injected.ssoExchangeTokenMonitor)
        profileRepository = injector.getInjected(identifiedBy: Injected.profileRepository)
        userProfileDatabase = injector.getInjected(identifiedBy: Injected.currentUserProfileDatabase)
        clientUserProfileDatabase = injector.getInjected(identifiedBy: Injected.clientUserProfileDatabase)
        postFeedsStore = injector.getInjected(identifiedBy: Injected.postFeedsStore)
        clientUserProvider = injector.getInjected(identifiedBy: Injected.clientUserProvider)

        Publishers.CombineLatest3(
            clientUserProvider.$clientUser,
            userDataStorage.$userData.removeDuplicates().receive(on: DispatchQueue.main),
            profileRepository.$profile.removeDuplicates().receive(on: DispatchQueue.main)
        )
        .sink { [unowned self] clientUser, userData, profile in
            let newConnectionState: ConnectionState
            if let userData, let clientUser {
                if let profile = profile ?? receivedProfile, userData.id == profile.userId,
                   profile.nickname.nilIfEmpty != nil {
                    newConnectionState = .connected(User(profile: profile, jwtToken: userData.jwtToken))
                } else {
                    let lockedFields: Set<ConnectionMode.SSOConfiguration.ProfileField>?
                    if case let .sso(ssoConfiguration) = connectionMode {
                        lockedFields = ssoConfiguration.appManagedFields
                    } else {
                        lockedFields = nil
                    }
                    newConnectionState = .profileCreationRequired(
                        clientProfile: clientUser.profile,
                        lockedFields: lockedFields)
                }
            } else if let clientUser {
                newConnectionState = .clientConnected(clientUser, nil)
            } else {
                newConnectionState = .notConnected
            }
            connectionState = newConnectionState
        }.store(in: &storage)

        ssoExchangeTokenMonitor
            .getJwtFromClientTokenResponsePublisher
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] response in
                // can ignore error that are threw because the connection state is also changed
                _ = try? processGetJwtFromClientResponse(response)
            }
            .store(in: &storage)
    }

    func connectUser(_ user: ClientUser, tokenProvider: @escaping () async throws -> String) async throws {
        let previousClientUserId = userDataStorage.clientUserData?.id
        let currentState = connectionState
        self.clientUserTokenProvider = tokenProvider
        // if client user changed, logout
        if previousClientUserId != user.userId {
            try await logout()
            if let previousClientUserId {
                try await clientUserProfileDatabase.delete(clientUserId: previousClientUserId)
            }
        }
        try await clientUserProfileDatabase.upsert(profile: user.profile, clientUserId: user.userId)
        // if state is not (connected or clientConnected without error for this client user), ask for a token
        let tokenNeeded: Bool
        switch currentState {
        case let .clientConnected(currentClientUser, error):
            tokenNeeded = currentClientUser.userId != user.userId || error != nil
        case .connected:
            tokenNeeded = previousClientUserId != user.userId
        default:
            tokenNeeded = true
        }
        if previousClientUserId != user.userId {
            userDataStorage.store(clientUserData: .init(id: user.userId, token: nil))
        }
        if tokenNeeded {
            Task {
                do {
                    let token = try await clientUserTokenProvider?()
                    userDataStorage.store(clientUserData: .init(id: user.userId, token: token))
                } catch {
                    print("Error while trying to fetch client user token: \(error)")
                }
            }
        }
    }

    func disconnectUser() async throws {
        let previousClientUserId = userDataStorage.clientUserData?.id
        self.clientUserTokenProvider = nil
        userDataStorage.store(clientUserData: nil)
        try await logout()
        if let previousClientUserId {
            try await clientUserProfileDatabase.delete(clientUserId: previousClientUserId)
        }
    }

    func linkClientUserToOctopusUser() async throws(ExchangeTokenError) {
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        // a client user with a callback to get token should have been set prior to this call
        guard let clientUserTokenProvider else { throw .unknown(InternalError.incorrectState) }
        guard case .clientConnected = connectionState else { throw .unknown(InternalError.incorrectState) }
        do {
            let token = try await clientUserTokenProvider()
            let response = try await remoteClient.userService.getJwt(clientToken: token)
            try processGetJwtFromClientResponse(response)
        } catch {
            if let linkClientUserToOctopusUserError = error as? ExchangeTokenError {
                throw linkClientUserToOctopusUserError
            } else if let error = error as? RemoteClientError {
                throw .server(ServerError(remoteClientError: error))
            } else {
                throw .unknown(error)
            }
        }
    }

    private func processGetJwtFromClientResponse(
        _ response: Com_Octopuscommunity_GetJwtFromClientSignedTokenResponse) throws(ExchangeTokenError) {
            guard case let .clientConnected(clientUser, _) = connectionState else { return }
            switch response.result {
            case .success(let success):
                if let profile = StorableCurrentUserProfile(from: success.profile, userId: success.userID) {
                    receivedProfile = CurrentUserProfile(storableProfile: profile, postFeedsStore: postFeedsStore)
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
                                userDataStorage.store(userData: .init(id: success.userID, clientId: clientUser.userId,
                                                                      jwtToken: success.jwt))

                                // Remove the token from the clientUserData
                                userDataStorage.store(clientUserData: .init(id: clientUser.userId, token: nil))
                                userInDbCancellable = nil
                            }
                    }
                } else {
                    userDataStorage.store(userData: .init(id: success.userID, clientId: clientUser.userId,
                                                          jwtToken: success.jwt))
                    // Remove the token from the clientUserData
                    userDataStorage.store(clientUserData: .init(id: clientUser.userId, token: nil))
                }
            case let .fail(failure):
                let detailedErrors = failure.errors.map { ExchangeTokenError.DetailedError(from: $0) }
                connectionState = .clientConnected(clientUser, .detailedErrors(detailedErrors))
                throw .detailedErrors(detailedErrors)
            case .none:
                connectionState = .clientConnected(clientUser, .unknown(nil))
                throw .unknown(nil)
            }
        }

    public func logout() async throws {
        let profileId: String? = if case let .connected(user) = connectionState {
            user.profile.id
        } else { nil }
        receivedProfile = nil
        userDataStorage.store(userData: nil)
        if let profileId {
            try await profileRepository.deleteCurrentUserProfile(profileId: profileId)
        }
    }

    public func sendMagicLink(to email: String) async throws(MagicLinkEmailEntryError) {
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
