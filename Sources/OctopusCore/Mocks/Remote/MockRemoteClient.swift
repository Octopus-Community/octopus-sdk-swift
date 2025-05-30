//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusRemoteClient
import OctopusDependencyInjection

class MockRemoteClient: OctopusRemoteClient, InjectableObject {
    static let injectedIdentifier = Injected.remoteClient
    let octoService: any OctoService
    let magicLinkService: any MagicLinkService
    let magicLinkStreamService: any MagicLinkStreamService
    let userService: any UserService
    let feedService: any FeedService
    let trackingService: any TrackingService
    let notificationService: any NotificationService

    init() {
        self.octoService = MockOctoService()
        self.magicLinkService = MockMagicLinkService()
        self.magicLinkStreamService = MockMagicLinkStreamService()
        self.userService = MockUserService()
        self.feedService = MockFeedService()
        self.trackingService = MockTrackingService()
        self.notificationService = MockNotificationService()
    }

    func set(appSessionId: String?) { }

    func set(octopusUISessionId: String?) { }

    func set(hasAccessToCommunity: Bool?) { }
}
