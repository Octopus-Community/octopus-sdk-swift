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

    /// Debug affordance: pretend the device is offline (or back online), whatever the real path says.
    ///
    /// A simulator reports a connection unconditionally (see the `init` below), so the offline states —
    /// the screen states, their retry, the toasts — cannot be reached there at all. This is what lets
    /// the sample exercise them without a device in airplane mode. `nil` restores the real path.
    func debugOverrideConnectionAvailable(_ available: Bool?)
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
    /// Set by the sample app; nil means "follow the real path". A subject rather than a stored
    /// property so the class stays `Sendable` like the rest of the monitor.
    private let debugOverride = CurrentValueSubject<Bool?, Never>(nil)

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "Octopus.NetworkMonitor")

    init() {
        monitor.pathUpdateHandler = { [unowned self] path in
            if let overriden = debugOverride.value {
                _connectionAvailablePublisher.send(overriden)
                return
            }
#if targetEnvironment(simulator)
            _connectionAvailablePublisher.send(true)
#else
            _connectionAvailablePublisher.send(path.status == .satisfied)
#endif
        }
    }

    func debugOverrideConnectionAvailable(_ available: Bool?) {
        debugOverride.send(available)
        if let available {
            _connectionAvailablePublisher.send(available)
        } else {
#if targetEnvironment(simulator)
            _connectionAvailablePublisher.send(true)
#else
            _connectionAvailablePublisher.send(monitor.currentPath.status == .satisfied)
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
