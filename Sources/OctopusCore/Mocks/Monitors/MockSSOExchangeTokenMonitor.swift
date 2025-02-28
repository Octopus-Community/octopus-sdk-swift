//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import DependencyInjection
import GrpcModels

class MockSSOExchangeTokenMonitor: SSOExchangeTokenMonitor, InjectableObject {
    static let injectedIdentifier = Injected.ssoExchangeTokenMonitor

    var getJwtFromClientTokenResponsePublisher: AnyPublisher<Com_Octopuscommunity_GetJwtFromClientSignedTokenResponse, Never> {
        $getJwtFromClientTokenResponse
            .filter { $0 != nil }
            .map { $0! }
            .eraseToAnyPublisher()
    }
    @Published var getJwtFromClientTokenResponse: Com_Octopuscommunity_GetJwtFromClientSignedTokenResponse?

    func start() { }

    func stop() { }
}
