//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import OctopusDependencyInjection
import OctopusGrpcModels

class MockUserProfileFetchMonitor: UserProfileFetchMonitor, InjectableObject {
    static let injectedIdentifier = Injected.userProfileFetchMonitor

    /// Tickets are taken when the response is set, as if its request had just been sent.
    var orderedUserProfileResponsePublisher: AnyPublisher<
        (Com_Octopuscommunity_GetPrivateProfileResponse, String, ProfileGamificationOrder.Ticket), Never> {
        $userProfileResponse
            .compactMap { $0 }
            .map { response, userId in (response, userId, ProfileGamificationOrder.nextTicket()) }
            .eraseToAnyPublisher()
    }
    @Published var userProfileResponse: (Com_Octopuscommunity_GetPrivateProfileResponse, String)?

    func start() { }

    func stop() { }

    func set(connectionInProgress: Bool) { }
}
