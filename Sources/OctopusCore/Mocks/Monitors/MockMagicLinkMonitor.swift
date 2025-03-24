//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import OctopusDependencyInjection
import OctopusGrpcModels

class MockMagicLinkMonitor: MagicLinkMonitor, InjectableObject {
    static let injectedIdentifier = Injected.magicLinkMonitor

    var magicLinkAuthenticationResponsePublisher: AnyPublisher<Com_Octopuscommunity_IsAuthenticatedResponse, Never> {
        $magicLinkAuthenticationResponse
            .filter { $0 != nil }
            .map { $0! }
            .eraseToAnyPublisher()
    }
    @Published var magicLinkAuthenticationResponse: Com_Octopuscommunity_IsAuthenticatedResponse?

    var getJwtFromClientTokenResponsePublisher: AnyPublisher<OctopusGrpcModels.Com_Octopuscommunity_IsAuthenticatedResponse, Never> { fatalError() }

    func start() { }

    func stop() { }
}
