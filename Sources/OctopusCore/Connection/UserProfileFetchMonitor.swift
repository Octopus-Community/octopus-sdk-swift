//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import os
import OctopusDependencyInjection
import OctopusRemoteClient
import GRPC
import OctopusGrpcModels

extension Injected {
    static let userProfileFetchMonitor = Injector.InjectedIdentifier<UserProfileFetchMonitor>()
}

protocol UserProfileFetchMonitor {
    /// Publisher of request response associated with the user id that triggered the request.
    var userProfileResponsePublisher: AnyPublisher<(Com_Octopuscommunity_GetPrivateProfileResponse, String), Never> { get }

    func start()
    func stop()
}

class UserProfileFetchMonitorDefault: UserProfileFetchMonitor, InjectableObject, @unchecked Sendable {
    public static let injectedIdentifier = Injected.userProfileFetchMonitor

    var userProfileResponsePublisher: AnyPublisher<(Com_Octopuscommunity_GetPrivateProfileResponse, String), Never> {
        $userProfileResponse
            .filter { $0 != nil }
            .map { $0! }
            .eraseToAnyPublisher()
    }
    @Published private var userProfileResponse: (Com_Octopuscommunity_GetPrivateProfileResponse, String)?

    private let injector: Injector
    private let remoteClient: OctopusRemoteClient
    private let userDataStorage: UserDataStorage
    private let authCallProvider: AuthenticatedCallProvider
    private let networkMonitor: NetworkMonitor

    private var storage: Set<AnyCancellable> = []
    private var magicLinkSubscription: Task<Void, Error>?

    init(injector: Injector) {
        self.injector = injector
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        authCallProvider = injector.getInjected(identifiedBy: Injected.authenticatedCallProvider)
        networkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor)
    }

    func start() {
        Publishers.CombineLatest(
            userDataStorage.$userData.removeDuplicates(by: { $0?.id == $1?.id }),
            networkMonitor.connectionAvailablePublisher
        )
        .map { userData, connectionAvailable -> UserDataStorage.UserData? in
            guard connectionAvailable else { return nil }
            guard let userData else { return nil }
            return userData
        }
        // do it only once when all requirements are met
        .removeDuplicates()
        .sink { userData in
            guard let userData else { return }
            Task { [self] in
                do {
                    let response = try await remoteClient.userService
                        .getPrivateProfile(
                            userId: userData.id,
                            authenticationMethod: try authCallProvider.authenticatedMethod(forceJwt: userData.jwtToken))
                    guard userDataStorage.userData?.id == userData.id else {
                        throw InternalError.userIdNotMatching
                    }
                    // Pass the user id that triggered the response to be sure to have consistent data.
                    userProfileResponse = (response, userData.id)
                } catch {
                    if #available(iOS 14, *) { Logger.profile.debug("Error while fetching user profile: \(error)") }
                    if let error = error as? RemoteClientError {
                        if case .notFound = error {
                            if #available(iOS 14, *) { Logger.profile.debug("NotFound received from server, logging out the user") }
                            let connectionRepository = injector.getInjected(identifiedBy: Injected.connectionRepository)
                            Task {
                                try await connectionRepository.logout()
                            }
                        }
                    }
                }
            }
        }.store(in: &storage)
    }

    func stop() {
        storage.removeAll()
    }
}
