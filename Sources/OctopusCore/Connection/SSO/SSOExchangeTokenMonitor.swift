//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import DependencyInjection
import RemoteClient
import GRPC
import GrpcModels

extension Injected {
    static let ssoExchangeTokenMonitor = Injector.InjectedIdentifier<SSOExchangeTokenMonitor>()
}

protocol SSOExchangeTokenMonitor {
    var getJwtFromClientTokenResponsePublisher: AnyPublisher<Com_Octopuscommunity_GetJwtFromClientSignedTokenResponse, Never> { get }

    func start()
    func stop()
}

class SSOExchangeTokenMonitorDefault: SSOExchangeTokenMonitor, InjectableObject, @unchecked Sendable {
    public static let injectedIdentifier = Injected.ssoExchangeTokenMonitor

    var getJwtFromClientTokenResponsePublisher: AnyPublisher<Com_Octopuscommunity_GetJwtFromClientSignedTokenResponse, Never> {
        $getJwtFromClientTokenResponse
            .filter { $0 != nil }
            .map { $0! }
            .eraseToAnyPublisher()
    }
    @Published private var getJwtFromClientTokenResponse: Com_Octopuscommunity_GetJwtFromClientSignedTokenResponse?

    private let remoteClient: RemoteClient
    private let userDataStorage: UserDataStorage
    private let networkMonitor: NetworkMonitor

    private var storage: Set<AnyCancellable> = []

    init(injector: Injector) {
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        networkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor)
    }

    func start() {
        // TODO: Djavan Do that only when needed => i.e. the first time, when there is no user token
        userDataStorage.$clientUserData
            .removeDuplicates()
            .filter { $0 != nil }
            .map { [unowned self] clientUserData in
                networkMonitor.connectionAvailablePublisher
                    .filter { $0 }
                    .map { connectionAvailable in
                        (connectionAvailable, clientUserData)
                    }.eraseToAnyPublisher()
            }
            .switchToLatest()
            .sink { [unowned self] connectionAvailable, clientUserData in
                guard connectionAvailable else { return }
                guard let clientUserData, let clientUserToken = clientUserData.token else { return }
                print("Get JWT from client token")
                Task { [self] in
                    do {
                        let response = try await remoteClient.userService.getJwt(clientToken: clientUserToken)
                        getJwtFromClientTokenResponse = response
                    } catch {
                        print("Error during sso token exchange: \(error)")
                        getJwtFromClientTokenResponse = .init()
                    }
                }
            }.store(in: &storage)
    }

    func stop() {
        storage.removeAll()
    }
}
