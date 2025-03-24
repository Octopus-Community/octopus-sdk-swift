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
    @Published private(set) public var connectionState = ConnectionState.notConnected

    public let connectionMode: ConnectionMode
    private let remoteClient: OctopusRemoteClient
    private let userDataStorage: UserDataStorage
    private let authCallProvider: AuthenticatedCallProvider
    private let networkMonitor: NetworkMonitor
    private let magicLinkMonitor: MagicLinkMonitor
    private let profileRepository: ProfileRepository
    private let userProfileDatabase: CurrentUserProfileDatabase
    private let postFeedsStore: PostFeedsStore
    private var storage: Set<AnyCancellable> = []
    private var userInDbCancellable: AnyCancellable?

    private var receivedProfile: CurrentUserProfile?
    private var latestDisconnectionReason: String?

    init(connectionMode: ConnectionMode, injector: Injector) {
        self.connectionMode = connectionMode
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        authCallProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)
        networkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor)
        magicLinkMonitor = injector.getInjected(identifiedBy: Injected.magicLinkMonitor)
        profileRepository = injector.getInjected(identifiedBy: Injected.profileRepository)
        userProfileDatabase = injector.getInjected(identifiedBy: Injected.currentUserProfileDatabase)
        postFeedsStore = injector.getInjected(identifiedBy: Injected.postFeedsStore)

        Publishers.CombineLatest3(
            userDataStorage.$magicLinkData.removeDuplicates().receive(on: DispatchQueue.main),
            userDataStorage.$userData.removeDuplicates().receive(on: DispatchQueue.main),
            profileRepository.$profile.removeDuplicates().receive(on: DispatchQueue.main)
        )
        .sink { [unowned self] magicLinkData, userData, profile in
            let newConnectionState: ConnectionState
            if let userData {
                if let profile = profile ?? receivedProfile, userData.id == profile.userId,
                   profile.nickname.nilIfEmpty != nil {
                    newConnectionState = .connected(User(profile: profile, jwtToken: userData.jwtToken))
                } else {
                    newConnectionState = .profileCreationRequired(clientProfile: .empty, lockedFields: nil)
                }
            } else if let magicLinkData {
                newConnectionState = .magicLinkSent(MagicLinkRequest(email: magicLinkData.email, error: nil))
            } else {
                newConnectionState = .notConnected
            }
            connectionState = newConnectionState
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
        let profileId: String? = if case let .connected(user) = connectionState {
            user.profile.id
        } else { nil }
        receivedProfile = nil
        userDataStorage.store(userData: nil)
        if let profileId {
            try await profileRepository.deleteCurrentUserProfile(profileId: profileId)
        }
    }

    public func deleteAccount(reason: DeleteAccountReason) async throws(AuthenticatedActionError) {
        guard case let .connected(user) = connectionState else { throw .userNotAuthenticated }
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

    @discardableResult
    private func processMagicLinkConfirmation(
        _ response: Com_Octopuscommunity_IsAuthenticatedResponse) throws(MagicLinkConfirmationError) -> Bool {
            guard case let .magicLinkSent(magicLinkRequest) = connectionState else { return false }
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
                                userDataStorage.store(userData: .init(id: success.userID, jwtToken: success.jwt))
                                userDataStorage.store(magicLinkData: nil)
                                userInDbCancellable = nil
                            }
                    }
                } else {
                    userDataStorage.store(userData: .init(id: success.userID, jwtToken: success.jwt))
                    userDataStorage.store(magicLinkData: nil)
                }
                return true
            case .error(let error):
                switch error.errorCode {
                case .notAuthenticatedYet:
                    return false
                case .expiredLink:
                    let error = MagicLinkConfirmationError.magicLinkExpired
                    connectionState = .magicLinkSent(MagicLinkRequest(email: magicLinkRequest.email, error: error))
                    throw error
                case .linkNotFound, .userNotFound, .invalidLink:
                    let error = MagicLinkConfirmationError.needNewMagicLink
                    connectionState = .magicLinkSent(MagicLinkRequest(email: magicLinkRequest.email, error: error))
                    throw error
                case .userBanned:
                    let error = MagicLinkConfirmationError.userBanned(error.message)
                    connectionState = .magicLinkSent(MagicLinkRequest(email: magicLinkRequest.email, error: error))
                    throw error
                case .unknownError, .UNRECOGNIZED(_):
                    let error = MagicLinkConfirmationError.unknown(nil)
                    connectionState = .magicLinkSent(MagicLinkRequest(email: magicLinkRequest.email, error: error))
                    throw error
                }
            case .none:
                let error = MagicLinkConfirmationError.unknown(nil)
                connectionState = .magicLinkSent(MagicLinkRequest(email: magicLinkRequest.email, error: error))
                throw error
            }
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
