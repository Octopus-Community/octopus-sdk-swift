//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import SwiftUI
import Octopus

/// ViewModel of the SSO View
///
/// This view models listen to `appUser` to pass it to the SDK and this is what you should do: as soon as your users
/// changes, inform the SDK about it.
@MainActor
class SSOWithAllAppManagedFieldsViewModel: ObservableObject {
    @Published var openLogin = false
    @Published var openEditProfile = false

    @Published var appUser: AppUser?
    @Published var octopus: OctopusSDK?

    @Published private var isDisplayed = false

    private let tokenProvider: TokenProvider
    private let appUserStore: AppUserStore
    private var storage = [AnyCancellable]()

    init() {
        self.tokenProvider = TokenProvider()
        self.appUserStore = AppUserStore(prefix: "AllAppManagedFields")

        appUser = appUserStore.user

        OctopusSDKProvider.instance.$octopus
            .sink { [unowned self] in
                octopus = $0
            }.store(in: &storage)

        Publishers.CombineLatest(
            $isDisplayed, // delay the reception to have the time to configure the sdk
            $appUser
        )
        .sink { [unowned self] in
            guard $0 else { return }
            userUpdated(appUser: $1)
            appUserStore.set(user: $1)
        }.store(in: &storage)
    }

    func onAppear() {
        // For this scenario, we need the SDK to be on a different connection mode
        OctopusSDKProvider.instance.createSDK(connectionMode: .sso(
            .init(
                appManagedFields: Set(ConnectionMode.SSOConfiguration.ProfileField.allCases),
                loginRequired: { [weak self] in
                    guard let self else { return }
                    openLogin = true
                }, modifyUser: { [weak self] _ in
                    guard let self else { return }
                    openEditProfile = true
                })
        ))
        isDisplayed = true
    }

    func onDisappear() {
        isDisplayed = false
    }

    /// Whenever your user is modified, inform the SDK as soon as possible.
    private func userUpdated(appUser: AppUser?) {
        guard let octopus else { return }
        if let appUser {
            let clientUser = ClientUser(
                userId: appUser.userId,
                profile: .init(nickname: appUser.nickname, bio: appUser.bio,
                               picture: appUser.picture,
                               ageInformation: appUser.ageInformation?.sdkValue))
            octopus.connectUser(
                clientUser,
                tokenProvider: { [weak self] in
                    guard let self else { throw NSError(domain: "", code: 0, userInfo: nil) }
                    return try await self.tokenProvider.getToken(userId: appUser.userId)
                })
        } else {
            octopus.disconnectUser()
        }
    }
}
