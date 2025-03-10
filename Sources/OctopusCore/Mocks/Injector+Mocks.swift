//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import DependencyInjection

// restrict to DEBUG versions for security reasons. This way, we are sure that no release build can use mocks
#if DEBUG
enum Mock {
    case remoteClient
    case authProvider
    case securedStorage
    case networkMonitor
    case magicLinkMonitor
    case ssoExchangeTokenMonitor
    case userProfileFetchMonitor
    case appStateMonitor
    case blockedUserIdsProvider
}

extension Injector {
    func registerMocks(_ mocks: Mock...) {
        for mock in mocks {
            switch mock {
            case .remoteClient:
                register { _ in MockRemoteClient() }
            case .authProvider:
                register { _ in MockAuthenticatedCallProvider() }
            case .securedStorage:
                register { _ in MockSecuredStorage() }
            case .networkMonitor:
                register { _ in MockNetworkMonitor() }
            case .magicLinkMonitor:
                register { _ in MockMagicLinkMonitor() }
            case .ssoExchangeTokenMonitor:
                register { _ in MockSSOExchangeTokenMonitor() }
            case .userProfileFetchMonitor:
                register { _ in MockUserProfileFetchMonitor() }
            case .appStateMonitor:
                register { _ in MockAppStateMonitor() }
            case .blockedUserIdsProvider:
                register { _ in MockBlockedUserIdsProvider() }
            }
        }
    }
}
#endif
