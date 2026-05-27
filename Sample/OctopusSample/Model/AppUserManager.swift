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
    @Published var connectionError: OctopusConnectUserError?

    /// Test-harness entitlements that get embedded in the next client-signed JWT minted by
    /// `TokenProvider`. In a real client app these are sourced from the backend session;
    /// here we let the tester edit them directly via the entitlements editor screens.
    var currentEntitlements: Set<Entitlement> = []

    private let appUserStore = AppUserStore()
    private let tokenProvider = TokenProvider()
    private var storage = [AnyCancellable]()
    private var userChangedInApp = false

    private init() {
        Publishers.CombineLatest(
            appUserStore.$user.removeDuplicates(),
            NotificationCenter.default.publisher(for: .apiKeyChanged).prepend(Notification(name: .apiKeyChanged))
        ).sink { [unowned self] appUser, _ in
            self.appUser = appUser
            let displayErrors = userChangedInApp
            userChangedInApp = false

            guard let octopus = OctopusSDKProvider.instance.octopus else { return }
            let sdkConfig = SDKConfigManager.instance.sdkConfig
            switch sdkConfig?.authKind {
            case .octopus: return
            default: break // if config is nil, or if sso, we can continue
            }

            if let appUser {
                let clientUser = ClientUser(
                    userId: appUser.userId,
                    profile: .init(nickname: appUser.nickname, bio: appUser.bio,
                                   picture: appUser.picture))
                Task { [weak self] in
                    guard let self else { return }
                    do {
                        try await octopus.connectUser(
                            clientUser,
                            tokenProvider: { [weak self] in
                                guard let self else { throw NSError(domain: "", code: 0, userInfo: nil) }
                                return try await self.tokenProvider.getClientUserToken(
                                    userId: appUser.userId,
                                    entitlements: self.currentEntitlements.map(\.rawValue).sorted()
                                )
                            })
                        await MainActor.run { self.connectionError = nil }
                    } catch {
                        print("Error while connecting user: \(error)")
                        if let error = error as? OctopusConnectUserError, displayErrors {
                            await MainActor.run { self.connectionError = error }
                        }
                    }
                }
            } else {
                Task {
                    do {
                        try await octopus.disconnectUser()
                    } catch {
                        print("Error while disconnecting user: \(error)")
                    }
                }
            }
        }.store(in: &storage)
    }

    func set(appUser: AppUser?) {
        userChangedInApp = true
        appUserStore.set(user: appUser)
    }
}
