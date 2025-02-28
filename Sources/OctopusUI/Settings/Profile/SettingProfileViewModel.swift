//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import Octopus

@MainActor
class SettingProfileViewModel: ObservableObject {

    let octopus: OctopusSDK

    @Published private(set) var email: String?

    private var storage = [AnyCancellable]()

    init(octopus: OctopusSDK) {
        self.octopus = octopus
        octopus.core.profileRepository.$profile
            .sink { [unowned self] profile in
                email = profile?.email
            }.store(in: &storage)
    }
}
