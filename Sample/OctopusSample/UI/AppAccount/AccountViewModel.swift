//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import SwiftUI
import Octopus

/// ViewModel the AccountView
@MainActor
class AccountViewModel: ObservableObject {
    @Published var openLogin = false
    @Published var openEditProfile = false

    @Published var appUser: AppUser?
    @Published var octopus: OctopusSDK?
    @Published var entitlementsDisplay: String = "—"

    private let appUserManager: AppUserManager
    private var storage = [AnyCancellable]()

    init() {
        self.appUserManager = AppUserManager.instance

        AppUserManager.instance.$appUser
            .removeDuplicates()
            .sink { [unowned self] in
                appUser = $0
            }.store(in: &storage)

        $appUser
            .removeDuplicates()
            .sink {
                AppUserManager.instance.set(appUser: $0)
            }.store(in: &storage)

        OctopusSDKProvider.instance.octopus?.$profile
            .map { profile -> String in
                let entitlements = profile?.entitlements ?? []
                guard !entitlements.isEmpty else { return "—" }
                return entitlements.sorted().joined(separator: ", ")
            }
            .removeDuplicates()
            .sink { [unowned self] in
                entitlementsDisplay = $0
            }.store(in: &storage)
    }
}
