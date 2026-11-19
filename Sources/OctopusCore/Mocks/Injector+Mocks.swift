//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusDependencyInjection

// restrict to DEBUG versions for security reasons. This way, we are sure that no release build can use mocks
#if DEBUG
enum Mock {
    case remoteClient
    case authProvider
    case securedStorage
    case networkMonitor
    case userProfileFetchMonitor
    case appStateMonitor
    case blockedUserIdsProvider
    case configRepository
    case backgroundTaskProvider
    /// An open community, with a closure stored in its own user defaults suite and a purger that deletes nothing.
    case communityClosure
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
            case .userProfileFetchMonitor:
                register { _ in MockUserProfileFetchMonitor() }
            case .appStateMonitor:
                register { _ in MockAppStateMonitor() }
            case .blockedUserIdsProvider:
                register { _ in MockBlockedUserIdsProvider() }
            case .configRepository:
                register { _ in MockConfigRepository() }
            case .backgroundTaskProvider:
                register { _ in MockBackgroundTaskProvider() }
            case .communityClosure:
                registerCommunityClosure(store: CommunityClosureStore(
                    apiKey: "apiKey", userDefaults: UserDefaults(suiteName: "MockCommunityClosure-\(UUID())")!))
            }
        }
    }

    /// Registers the closure repository on `store`, which a test can fill before, and a purger that deletes nothing.
    func registerCommunityClosure(store: CommunityClosureStore) {
        register { _ in MockCommunityClosurePurger() }
        register { CommunityClosureRepository(injector: $0, store: store) }
    }
}
#endif
