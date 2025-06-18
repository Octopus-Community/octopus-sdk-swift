//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import OctopusDependencyInjection
import OctopusGrpcModels

class MockUserProfileFetchMonitor: UserProfileFetchMonitor, InjectableObject {
    static let injectedIdentifier = Injected.userProfileFetchMonitor

    var userProfileResponsePublisher: AnyPublisher<(Com_Octopuscommunity_GetPrivateProfileResponse, String), Never> {
        $userProfileResponse
            .filter { $0 != nil }
            .map { $0! }
            .eraseToAnyPublisher()
    }
    @Published var userProfileResponse: (Com_Octopuscommunity_GetPrivateProfileResponse, String)?

    func start() { }

    func stop() { }
}
