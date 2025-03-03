//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import DependencyInjection

class MockAppStateMonitor: AppStateMonitor, InjectableObject {
    static let injectedIdentifier = Injected.appStateMonitor

    var appStatePublisher: AnyPublisher<AppState, Never> { $appState.eraseToAnyPublisher() }
    @Published var appState = AppState.active

    func start() { }

    func stop() { }
}
