//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import UIKit
import Octopus

@MainActor
class OpenUserProfileBubbleViewModel: ObservableObject {

    @Published private(set) var avatar: Author.Avatar = .notConnected

    let octopus: OctopusSDK

    private var storage = [AnyCancellable]()

    init(octopus: OctopusSDK) {
        self.octopus = octopus

        octopus.core.profileRepository.$profile.sink { [unowned self] in
            guard let profile = $0 else {
                avatar = .notConnected
                return
            }
            if let pictureUrl = profile.pictureUrl {
                avatar = .image(url: pictureUrl, name: profile.nickname)
            } else {
                avatar = .defaultImage(name: profile.nickname)
            }
        }.store(in: &storage)
    }
}
