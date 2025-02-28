//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import SwiftUI
import Octopus

/// ViewModel of the SSO View
///
/// This view models listen to `appManagedFields` in order to reset the sdk with the new value.
/// It also listens to `appUser` to pass it to the SDK and this is what you should do: as soon as your users changes,
/// inform the SDK about it.
@MainActor
class SSOViewModel: ObservableObject {
    @Published var openLogin = false
    @Published var openEditProfile = false

    @Published var appUser: AppUser?
    @Published var appManagedFields: Set<ConnectionMode.SSOConfiguration.ProfileField> = []

    @Published private var isDisplayed = false

    private let model: SampleModel
    private let tokenProvider: TokenProvider
    private let appUserStore: AppUserStore
    private var storage = [AnyCancellable]()

    init(model: SampleModel) {
        self.model = model
        self.tokenProvider = TokenProvider()
        self.appUserStore = AppUserStore()

        appUser = appUserStore.user

        Publishers.CombineLatest(
            $isDisplayed, // delay the reception to have the time to configure the sdk
            $appUser
        )
        .sink { [unowned self] in
            guard $0 else { return }
            userUpdated(appUser: $1)
            appUserStore.set(user: $1)
        }.store(in: &storage)

        $appManagedFields
            .sink { [unowned self] appManagedFields in
                guard isDisplayed else { return }
                // For this scenario, we need the SDK to be on a different connection mode
                model.setConnectionMode(.sso(
                    .init(
                        appManagedFields: appManagedFields,
                        loginRequired: { [weak self] in
                            guard let self else { return }
                            openLogin = true
                        }, modifyUser: { [weak self] _ in
                            guard let self else { return }
                            openEditProfile = true
                        })
                ))

                userUpdated(appUser: appUser)
            }.store(in: &storage)
    }

    func onAppear() {
        // For this scenario, we need the SDK to be on a different connection mode
        model.setConnectionMode(
            .sso(
                .init(
                    appManagedFields: appManagedFields,
                    loginRequired: { [weak self] in
                        guard let self else { return }
                        openLogin = true
                    }, modifyUser: { [weak self] _ in
                        guard let self else { return }
                        openEditProfile = true
                    })
            )
        )
        isDisplayed = true
    }

    func onDisappear() {
        isDisplayed = false
        model.setConnectionMode(.octopus(deepLink: nil))
    }

    /// Whenever your user is modified, inform the SDK as soon as possible.
    private func userUpdated(appUser: AppUser?) {
        if let appUser {
            let clientUser = ClientUser(
                userId: appUser.userId,
                profile: .init(nickname: appUser.nickname, bio: appUser.bio,
                               picture: appUser.picture,
                               ageInformation: appUser.ageInformation?.sdkValue))
            model.octopus.connectUser(
                clientUser,
                tokenProvider: { [weak self] in
                    guard let self else { throw NSError(domain: "", code: 0, userInfo: nil) }
                    return try await self.tokenProvider.getToken(userId: appUser.userId)
                })
        } else {
            model.octopus.disconnectUser()
        }
    }
}

extension AppUser.AgeInfo {
    var sdkValue: ClientUser.AgeInformation {
        switch self {
        case .lessThan16:
            return .underaged
        case .moreThan16:
            return .legalAgeReached
        }
    }
}
