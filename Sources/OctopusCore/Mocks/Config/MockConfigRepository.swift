//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import os
import OctopusRemoteClient
import OctopusDependencyInjection

class MockConfigRepository: ConfigRepository, InjectableObject, @unchecked Sendable {
    static let injectedIdentifier = Injected.configRepository

    @Published private(set) var communityConfig: CommunityConfig?
    var communityConfigPublisher: AnyPublisher<CommunityConfig?, Never> { $communityConfig.eraseToAnyPublisher() }

    @Published private(set) var userConfig: UserConfig?
    var userConfigPublisher: AnyPublisher<UserConfig?, Never> { $userConfig.eraseToAnyPublisher() }

    init() {
        userConfig = UserConfig(canAccessCommunity: true, accessDeniedMessage: nil)
    }

    func refreshCommunityConfig() async throws(ServerCallError) {

    }

    public func overrideCommunityAccess(_ access: Bool) async throws {
       userConfig = UserConfig(canAccessCommunity: access, accessDeniedMessage: nil)
    }

    public func refreshCommunityAccess() async throws(ServerCallError) {

    }

    public func debugOverrideProfileFieldsLock(_ lock: ProfileFieldsLock?) {
        guard let communityConfig, let lock else { return }
        self.communityConfig = communityConfig.withProfileFieldsLock(lock)
    }

    public func debugOverrideContentOptions(_ options: ContentOptions?) {
        guard let communityConfig, let options else { return }
        self.communityConfig = communityConfig.withContentOptions(options)
    }
}
