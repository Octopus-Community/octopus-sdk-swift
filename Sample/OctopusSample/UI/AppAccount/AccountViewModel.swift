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
            .sink {
                AppUserManager.instance.set(appUser: $0)
            }.store(in: &storage)
    }
}
