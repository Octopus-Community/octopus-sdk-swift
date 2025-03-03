//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import DependencyInjection

class MockNetworkMonitor: NetworkMonitor, InjectableObject {
    static let injectedIdentifier = Injected.networkMonitor

    var connectionAvailablePublisher: AnyPublisher<Bool, Never> { $connectionAvailable.eraseToAnyPublisher() }
    @Published var connectionAvailable = true

    func start() { }

    func stop() { }
}
