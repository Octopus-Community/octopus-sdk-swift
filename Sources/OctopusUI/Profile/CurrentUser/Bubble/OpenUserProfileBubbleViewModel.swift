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
    @Published private(set) var badgeCount: String?

    let octopus: OctopusSDK

    private var storage = [AnyCancellable]()

    init(octopus: OctopusSDK) {
        self.octopus = octopus

        octopus.core.profileRepository.profilePublisher.sink { [unowned self] in
            guard let profile = $0 else {
                avatar = .notConnected
                badgeCount = nil
                return
            }
            if let pictureUrl = profile.pictureUrl {
                avatar = .image(url: pictureUrl, name: profile.nickname)
            } else {
                avatar = .defaultImage(name: profile.nickname)
            }
            badgeCount = switch profile.notificationBadgeCount {
            case 0: nil
            case 1..<100: String(profile.notificationBadgeCount)
            default: "+99"
            }
        }.store(in: &storage)
    }
}
