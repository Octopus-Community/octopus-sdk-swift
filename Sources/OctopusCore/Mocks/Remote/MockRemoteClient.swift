//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import OctopusRemoteClient
import OctopusDependencyInjection

class MockRemoteClient: OctopusRemoteClient, InjectableObject {
    static let injectedIdentifier = Injected.remoteClient
    let octoService: any OctoService
    let userService: any UserService
    let feedService: any FeedService
    let trackingService: any TrackingService
    let notificationService: any NotificationService
    let apiKeyService: any ApiKeyService

    init() {
        self.octoService = MockOctoService()
        self.userService = MockUserService()
        self.feedService = MockFeedService()
        self.trackingService = MockTrackingService()
        self.notificationService = MockNotificationService()
        self.apiKeyService = MockApiKeyService()
    }

    func set(appSessionId: String?) { }

    func set(octopusUISessionId: String?) { }

    func set(hasAccessToCommunity: Bool?) { }

    func set(localeIdentifier: String) { }

    /// The last value passed to `set(callsBlocked:)`.
    private(set) var callsBlocked = false

    func set(callsBlocked: Bool) {
        self.callsBlocked = callsBlocked
    }

    /// The handler passed to `set(communityClosedHandler:)`. Called by the tests to stand for a call the server refused
    /// because the community is closed.
    private(set) var communityClosedHandler: (@Sendable () -> Void)?

    func set(communityClosedHandler: (@Sendable () -> Void)?) {
        self.communityClosedHandler = communityClosedHandler
    }

    /// The handler passed to `set(accessRefusedHandler:)`. Called by the tests to stand for a call the server refused
    /// to a user it no longer lets in.
    private(set) var accessRefusedHandler: (@Sendable (_ endsSession: Bool) -> Void)?

    func set(accessRefusedHandler: (@Sendable (_ endsSession: Bool) -> Void)?) {
        self.accessRefusedHandler = accessRefusedHandler
    }
}
