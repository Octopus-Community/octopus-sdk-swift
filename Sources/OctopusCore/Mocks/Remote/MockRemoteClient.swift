//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import RemoteClient
import DependencyInjection

class MockRemoteClient: RemoteClient, InjectableObject {
    static let injectedIdentifier = Injected.remoteClient
    let octoService: any OctoService
    let magicLinkService: any MagicLinkService
    let magicLinkStreamService: any MagicLinkStreamService
    let userService: any UserService
    let feedService: any FeedService

    init() {
        self.octoService = MockOctoService()
        self.magicLinkService = MockMagicLinkService()
        self.magicLinkStreamService = MockMagicLinkStreamService()
        self.userService = MockUserService()
        self.feedService = MockFeedService()
    }
}
