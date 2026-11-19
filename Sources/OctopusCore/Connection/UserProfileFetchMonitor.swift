//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import os
import OctopusDependencyInjection
import OctopusRemoteClient
#if canImport(GRPC)
import GRPC
#else
import GRPCSwift
#endif
import OctopusGrpcModels

extension Injected {
    static let userProfileFetchMonitor = Injector.InjectedIdentifier<UserProfileFetchMonitor>()
}

protocol UserProfileFetchMonitor {
    /// Publisher of request response associated with the user id that triggered the request, and with the ticket taken
    /// when the request was sent (see `ProfileGamificationOrder`).
    var orderedUserProfileResponsePublisher: AnyPublisher<
        (Com_Octopuscommunity_GetPrivateProfileResponse, String, ProfileGamificationOrder.Ticket), Never> { get }

    func start()
    func stop()
    func set(connectionInProgress: Bool)
}

class UserProfileFetchMonitorDefault: UserProfileFetchMonitor, InjectableObject, @unchecked Sendable {
    public static let injectedIdentifier = Injected.userProfileFetchMonitor

    var orderedUserProfileResponsePublisher: AnyPublisher<
        (Com_Octopuscommunity_GetPrivateProfileResponse, String, ProfileGamificationOrder.Ticket), Never> {
        $userProfileResponse
            .filter { $0 != nil }
            .map { $0! }
            .eraseToAnyPublisher()
    }
    @Published private var userProfileResponse:
        (Com_Octopuscommunity_GetPrivateProfileResponse, String, ProfileGamificationOrder.Ticket)?

    private weak var injector: Injector?
    private let remoteClient: OctopusRemoteClient
    private let userDataStorage: UserDataStorage
    private let authCallProvider: AuthenticatedCallProvider
    private let networkMonitor: NetworkMonitor
    private let appStateMonitor: AppStateMonitor

    private var storage: Set<AnyCancellable> = []

    @Published private var connectionInProgress = false

    /// The id of the last user `start()` saw `userDataStorage` publish. A fetch checks the session against it, not
    /// against `userDataStorage.userData`: `@Published` publishes a value before it writes it, so the fetch a new user
    /// triggers could still read the previous user there, and drop its own response for good.
    private var latestUserId: String?
    private let latestUserIdLock = NSLock()

    init(injector: Injector) {
        self.injector = injector
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        authCallProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)
        networkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor)
        appStateMonitor = injector.getInjected(identifiedBy: Injected.appStateMonitor)
        // See `PublishedPublishers`: done before anything can write these values.
        PublishedPublishers.create($userProfileResponse, $connectionInProgress)
    }

    func start() {
        userDataStorage.$userData.removeDuplicates(by: { $0?.id == $1?.id })
            // recorded before the fetch below can start
            .handleEvents(receiveOutput: { [weak self] in self?.setLatestUserId($0?.id) })
            // do it only once when all requirements are met
            .map { [unowned self] userData in
                return Publishers.CombineLatest3(
                    networkMonitor.connectionAvailablePublisher.removeDuplicates(),
                    appStateMonitor.appStatePublisher.removeDuplicates(),
                    $connectionInProgress.removeDuplicates()
                )
                // do it only once when all requirements are met
                .filter { $0 && $1 == .active && !$2 }
                .first()
                .map { _ in userData }
            }
            .switchToLatest()
            .sink { userData in
                guard let userData else { return }
                Task { [self] in
                    do {
                        let (response, gamificationTicket) = try await ProfileGamificationOrder.send {
                            try await remoteClient.userService.getPrivateProfile(
                                userId: userData.id,
                                authenticationMethod: try authCallProvider.authenticatedMethod(forceJwt: userData.jwtToken))
                        }
                        guard isLatestUser(userData.id) else {
                            throw InternalError.userIdNotMatching
                        }
                        // Pass the user id that triggered the response to be sure to have consistent data.
                        userProfileResponse = (response, userData.id, gamificationTicket)
                    } catch {
                        if #available(iOS 14, *) { Logger.profile.debug("Error while fetching user profile: \(error)") }
                        if let error = error as? RemoteClientError {
                            if case .notFound = error {
                                if #available(iOS 14, *) { Logger.profile.debug("NotFound received from server, logging out the user") }
                                let connectionRepository = injector?.getInjected(identifiedBy: Injected.connectionRepository)
                                Task {
                                    do {
                                        try await connectionRepository?.logout()
                                    } catch {
                                        if #available(iOS 14, *) {
                                            Logger.connection.debug("Error while logging out the user: \(error)")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }.store(in: &storage)
    }

    func stop() {
        storage.removeAll()
        // a fetch still in flight is for a session the monitor no longer follows
        setLatestUserId(nil)
    }

    func set(connectionInProgress: Bool) {
        self.connectionInProgress = connectionInProgress
    }

    private func setLatestUserId(_ userId: String?) {
        latestUserIdLock.lock()
        defer { latestUserIdLock.unlock() }
        latestUserId = userId
    }

    private func isLatestUser(_ userId: String) -> Bool {
        latestUserIdLock.lock()
        defer { latestUserIdLock.unlock() }
        return latestUserId == userId
    }
}
