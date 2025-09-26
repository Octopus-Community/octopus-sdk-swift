//
//  Copyright © 2025 Octopus Community. All rights reserved.
//


//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import SwiftUI
import Octopus

/// ViewModel of the AppLoginScreen and AppEditUserScreen
///
/// This view models transmits the app user changes to the AppUserManager.
@MainActor
class AppUserViewModel: ObservableObject {
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
