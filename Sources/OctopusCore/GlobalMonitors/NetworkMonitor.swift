//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Network
@preconcurrency import Combine
import OctopusDependencyInjection

extension Injected {
    static let networkMonitor = Injector.InjectedIdentifier<NetworkMonitor>()
}

protocol NetworkMonitor {
    var connectionAvailable: Bool { get }
    var connectionAvailablePublisher: AnyPublisher<Bool, Never> { get }

    func start()
    func stop()
}

final class NetworkMonitorDefault: NetworkMonitor, InjectableObject, Sendable {
    static let injectedIdentifier = Injected.networkMonitor

    var connectionAvailablePublisher: AnyPublisher<Bool, Never> {
        _connectionAvailablePublisher
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    var connectionAvailable: Bool { _connectionAvailablePublisher.value }

    private let _connectionAvailablePublisher = CurrentValueSubject<Bool, Never>(false)

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "Octopus.NetworkMonitor")

    init() {
        monitor.pathUpdateHandler = { [unowned self] path in
#if targetEnvironment(simulator)
            _connectionAvailablePublisher.send(true)
#else
            _connectionAvailablePublisher.send(path.status == .satisfied)
#endif
        }
    }

    deinit {
        stop()
    }

    func start() {
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }
}
