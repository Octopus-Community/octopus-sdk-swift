//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import os
import OctopusDependencyInjection
import OctopusRemoteClient
import OctopusGrpcModels

extension Injected {
    static let magicLinkMonitor = Injector.InjectedIdentifier<MagicLinkMonitor>()
}

protocol MagicLinkMonitor {
    var magicLinkAuthenticationResponsePublisher: AnyPublisher<Com_Octopuscommunity_IsAuthenticatedResponse, Never> { get }

    func start()
    func stop()
}

class MagicLinkMonitorDefault: MagicLinkMonitor, InjectableObject, @unchecked Sendable {
    public static let injectedIdentifier = Injected.magicLinkMonitor

    var magicLinkAuthenticationResponsePublisher: AnyPublisher<Com_Octopuscommunity_IsAuthenticatedResponse, Never> {
        $magicLinkAuthenticationResponse
            .filter { $0 != nil }
            .map { $0! }
            .eraseToAnyPublisher()
    }
    @Published private var magicLinkAuthenticationResponse: Com_Octopuscommunity_IsAuthenticatedResponse?

    private let remoteClient: OctopusRemoteClient
    private let userDataStorage: UserDataStorage
    private let networkMonitor: NetworkMonitor
    private let appStateMonitor: AppStateMonitor

    private var storage: Set<AnyCancellable> = []

    init(injector: Injector) {
        remoteClient = injector.getInjected(identifiedBy: Injected.remoteClient)
        userDataStorage = injector.getInjected(identifiedBy: Injected.userDataStorage)
        networkMonitor = injector.getInjected(identifiedBy: Injected.networkMonitor)
        appStateMonitor = injector.getInjected(identifiedBy: Injected.appStateMonitor)
    }

    func start() {
        userDataStorage.$magicLinkData
            .filter { $0 != nil }
            .map { [unowned self] magicLink in
                Publishers.CombineLatest(
                    networkMonitor.connectionAvailablePublisher,
                    // ignore first to be reactive to changes only: if app is already active, we want to ignore it
                    appStateMonitor.appStatePublisher.dropFirst()
                )
                .filter { $0 && $1 == .active }
                .map { connectionAvailable, appState in
                    (connectionAvailable, appState, magicLink)
                }.eraseToAnyPublisher()
            }.switchToLatest()
            .sink { [unowned self] connectionAvailable, appState, magicLinkData in
                guard connectionAvailable else { return }
                guard appState == .active else { return }
                guard let magicLinkData else { return }
                Task { [self] in
                    do {
                        let response = try await remoteClient.magicLinkService.getJwt(magicLinkId: magicLinkData.magicLinkId,
                                                                                      email: magicLinkData.email)
                        magicLinkAuthenticationResponse = response
                    } catch {
                        if #available(iOS 14, *) { Logger.connection.debug("Error during magic link automatic result fetching: \(error)") }
                    }
                }
            }.store(in: &storage)
    }

    func stop() {
        storage.removeAll()
    }
}
