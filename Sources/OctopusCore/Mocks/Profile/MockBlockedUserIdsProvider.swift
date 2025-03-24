//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import OctopusDependencyInjection

class MockBlockedUserIdsProvider: BlockedUserIdsProvider, InjectableObject {
    static let injectedIdentifier = Injected.blockedUserIdsProvider

    var blockedUserIdsPublisher: AnyPublisher<[String], Never> {
        $blockedUserIds
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    @Published private(set) var blockedUserIds = [String]()

    func start() { }

    func stop() { }

    func mockBlockedUserIds(_ blockedUserIds: [String]) {
        self.blockedUserIds = blockedUserIds
    }
}
