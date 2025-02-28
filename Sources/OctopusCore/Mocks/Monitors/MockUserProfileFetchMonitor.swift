//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import DependencyInjection
import GrpcModels

class MockUserProfileFetchMonitor: UserProfileFetchMonitor, InjectableObject {
    static let injectedIdentifier = Injected.userProfileFetchMonitor

    var userProfileResponsePublisher: AnyPublisher<Com_Octopuscommunity_GetPrivateProfileResponse, Never> {
        $userProfileResponse
            .filter { $0 != nil }
            .map { $0! }
            .eraseToAnyPublisher()
    }
    @Published var userProfileResponse: Com_Octopuscommunity_GetPrivateProfileResponse?

    func start() { }

    func stop() { }
}
