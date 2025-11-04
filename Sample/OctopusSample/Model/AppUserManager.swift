//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus

/// This class mimicks the way the real app is managing the connected user.
/// As soon as it has a user or its profile changes, it calls `octopus.connectUser` or `octopus.disconnectUser`
class AppUserManager {
    static let instance = AppUserManager()

    @Published var appUser: AppUser?

    private let appUserStore = AppUserStore()
    private let tokenProvider = TokenProvider()
    private var storage = [AnyCancellable]()

    private init() {
        appUserStore.$user
            .removeDuplicates()
            .sink { [unowned self] in
                appUser = $0

                let octopus = OctopusSDKProvider.instance.octopus
                let sdkConfig = SDKConfigManager.instance.sdkConfig
                guard case .sso = sdkConfig?.authKind, let octopus else { return }
                if let appUser {
                    let clientUser = ClientUser(
                        userId: appUser.userId,
                        profile: .init(nickname: appUser.nickname, bio: appUser.bio,
                                       picture: appUser.picture))
                    octopus.connectUser(
                        clientUser,
                        tokenProvider: { [weak self] in
                            guard let self else { throw NSError(domain: "", code: 0, userInfo: nil) }
                            return try await self.tokenProvider.getClientUserToken(userId: appUser.userId)
                        })
                } else {
                    octopus.disconnectUser()
                }
            }.store(in: &storage)
    }

    func set(appUser: AppUser?) {
        appUserStore.set(user: appUser)
    }
}
