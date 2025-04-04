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
    @Published private(set) public var connectionState = ConnectionState.notConnected

    public let connectionMode: ConnectionMode
    private let remoteClient: OctopusRemoteClient
    private let userDataStorage: UserDataStorage
    private let authCallProvider: AuthenticatedCallProvider
    private let networkMonitor: NetworkMonitor
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

    private var connectionStateIsSet = false

    init(connectionMode: ConnectionMode, injector: Injector) {
        self.connectionMode = connectionMode
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        authCallProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)
        networkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor)
        profileRepository = injector.getInjected(identifiedBy: Injected.profileRepository)
        userProfileDatabase = injector.getInjected(identifiedBy: Injected.currentUserProfileDatabase)
        clientUserProfileDatabase = injector.getInjected(identifiedBy: Injected.clientUserProfileDatabase)
        postFeedsStore = injector.getInjected(identifiedBy: Injected.postFeedsStore)
        clientUserProvider = injector.getInjected(identifiedBy: Injected.clientUserProvider)

        Publishers.CombineLatest3(
            // ensure that clientUser value is not the initial one
            Publishers.CombineLatest(
                clientUserProvider.$clientUser,
                clientUserProvider.$hasLoadedClientUser.filter { $0 }
            ).map { $0.0 }.removeDuplicates(),
            userDataStorage.$userData.removeDuplicates().receive(on: DispatchQueue.main),
            // ensure that profile value is not the initial one
            Publishers.CombineLatest(
                profileRepository.$profile,
                profileRepository.$hasLoadedProfile.filter { $0 }
            ).map { $0.0 }.removeDuplicates().receive(on: DispatchQueue.main)
        )
        .receive(on: DispatchQueue.main)
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
                var exchangeTokenError: ExchangeTokenError?
                if case let .clientConnected(currentClientUser, currentExchangeTokenError) = connectionState,
                   clientUser.userId == currentClientUser.userId {
                    exchangeTokenError = currentExchangeTokenError
                }
                newConnectionState = .clientConnected(clientUser, exchangeTokenError)
            } else {
                newConnectionState = .notConnected
            }
            connectionState = newConnectionState
            connectionStateIsSet = true
        }.store(in: &storage)
    }

    func connectUser(_ user: ClientUser, tokenProvider: @escaping () async throws -> String) async throws {
        let previousClientUserId = userDataStorage.clientUserData?.id
        // since connection state is not set immediatly, we need to wait for its first "real" value, not the one that
        // it has been init with.
        try? await TaskUtils.wait(for: connectionStateIsSet)
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
        // if state is not connected to the same user, ask for a token
        let tokenNeeded: Bool
        switch currentState {
        case .connected, .profileCreationRequired:
            tokenNeeded = previousClientUserId != user.userId
        default:
            tokenNeeded = true
        }
        if previousClientUserId != user.userId {
            userDataStorage.store(clientUserData: .init(id: user.userId))
        }
        if tokenNeeded {
            Task {
                do {
                    try await doLinkClientUserToOctopusUser(clientUserId: user.userId)
                } catch {
                    if #available(iOS 14, *) { Logger.connection.debug("Error while trying to fetch client user token: \(error)") }
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
        guard case let .clientConnected(clientUser, _) = connectionState else { throw .unknown(InternalError.incorrectState) }
        try await doLinkClientUserToOctopusUser(clientUserId: clientUser.userId)
    }

    private func doLinkClientUserToOctopusUser(clientUserId: String) async throws(ExchangeTokenError) {
        guard networkMonitor.connectionAvailable else { throw .noNetwork }
        // a client user with a callback to get token should have been set prior to this call
        guard let clientUserTokenProvider else { throw .unknown(InternalError.incorrectState) }
        do {
            if #available(iOS 14, *) { Logger.connection.trace("Asking for client user token") }
            let token = try await clientUserTokenProvider()
            if #available(iOS 14, *) { Logger.connection.trace("Exchanging client user token for Octopus JWT") }
            let response = try await remoteClient.userService.getJwt(clientToken: token)
            try processGetJwtFromClientResponse(response, clientUserId: clientUserId)
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
        _ response: Com_Octopuscommunity_GetJwtFromClientSignedTokenResponse,
        clientUserId: String) throws(ExchangeTokenError) {
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
                                userDataStorage.store(userData: .init(id: success.userID, clientId: clientUserId,
                                                                      jwtToken: success.jwt))

                                userInDbCancellable = nil
                            }
                    }
                } else {
                    userDataStorage.store(userData: .init(id: success.userID, clientId: clientUserId,
                                                          jwtToken: success.jwt))
                }
            case let .fail(failure):
                let detailedErrors = failure.errors.map { ExchangeTokenError.DetailedError(from: $0) }
                let clientUser: ClientUser
                if case let .clientConnected(currentClientUser, _) = connectionState,
                    currentClientUser.userId == clientUserId {
                    clientUser = currentClientUser
                } else {
                    clientUser = ClientUser(userId: clientUserId, profile: .empty)
                }
                connectionState = .clientConnected(clientUser, .detailedErrors(detailedErrors))
                throw .detailedErrors(detailedErrors)
            case .none:
                let clientUser: ClientUser
                if case let .clientConnected(currentClientUser, _) = connectionState,
                    currentClientUser.userId == clientUserId {
                    clientUser = currentClientUser
                } else {
                    clientUser = ClientUser(userId: clientUserId, profile: .empty)
                }
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
