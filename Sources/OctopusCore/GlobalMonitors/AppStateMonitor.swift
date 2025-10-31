//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
@preconcurrency import Combine
import OctopusDependencyInjection
import UIKit

extension Injected {
    static let appStateMonitor = Injector.InjectedIdentifier<AppStateMonitor>()
}

// Type representing application state
enum AppState {
    /// App is in background
    case background
    /// App is in foreground
    case active
    /// Convenience initializer from `UIApplication.State`
    fileprivate init(applicationState: UIApplication.State) {
        switch applicationState {
        case .inactive, .active: self = .active
        case .background: self = .background
        @unknown default: self = .active
        }
    }
}

protocol AppStateMonitor {
    var appStatePublisher: AnyPublisher<AppState?, Never> { get }
    var appState: AppState? { get }

    func start()
    func stop()
}

final class AppStateMonitorDefault: AppStateMonitor, InjectableObject, @unchecked Sendable {
    static let injectedIdentifier = Injected.appStateMonitor

    var appStatePublisher: AnyPublisher<AppState?, Never> { $appState.eraseToAnyPublisher() }
    /// Current state of the app
    @Published private(set) var appState: AppState?

    private var storage: Set<AnyCancellable> = []

    func start() {
        // The UIApplication.shared.applicationState is changed from .background to .active after
        // `applicationDidFinishLaunching` function has returned. In that case, no notification is fired.
        // Hence, if this init is called during app startup, state is still .background and no notification is received
        // when it changes to .active. To fix this, set again the state at the next run loop (i.e. after
        // `applicationDidFinishLaunching` has returned).
        DispatchQueue.main.async {
            self.appState = AppState(applicationState: UIApplication.shared.applicationState)
        }
        NotificationCenter.default
            .publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [unowned self] _ in self.appState = .background }
            .store(in: &storage)

        NotificationCenter.default
            .publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [unowned self] _ in self.appState = .active }
            .store(in: &storage)
    }

    func stop() {
        storage = []
    }
}
