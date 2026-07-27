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

    /// The config `refreshCommunityConfig()` will apply on its next call, or `nil` to keep the no-op
    /// default behavior. Lets tests simulate the cold-start guard in
    /// `ProfileRepository.fetchProfile(byProfileId:)` / `fetchProfile(byClientUserId:)`: a config that
    /// only becomes available once the (mocked) refresh is triggered.
    private var nextRefreshCommunityConfig: CommunityConfig?

    init() {
        userConfig = UserConfig(canAccessCommunity: true, accessDeniedMessage: nil)
    }

    func injectNextRefreshCommunityConfig(_ config: CommunityConfig) {
        nextRefreshCommunityConfig = config
    }

    func refreshCommunityConfig() async throws(ServerCallError) {
        if let nextRefreshCommunityConfig {
            communityConfig = nextRefreshCommunityConfig
            self.nextRefreshCommunityConfig = nil
        }
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

    public func debugOverrideExposeClientUserId(_ enabled: Bool?) {
        guard let communityConfig, let enabled else { return }
        self.communityConfig = communityConfig.withExposeClientUserId(enabled)
    }

    public func debugOverrideTermsAcceptanceMode(_ mode: TermsAcceptanceMode?) {
        guard let communityConfig, let mode else { return }
        self.communityConfig = communityConfig.withTermsAcceptanceMode(mode)
    }
}
