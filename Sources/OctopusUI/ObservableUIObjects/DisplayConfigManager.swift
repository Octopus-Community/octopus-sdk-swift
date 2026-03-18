//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus
import OctopusCore

/// Object that holds the display config
@MainActor
final class DisplayConfigManager: ObservableObject {
    private let octopus: OctopusSDK

    @Published private(set) var poweredByConfig: DisplayConfig.PoweredByOctopus = .normal

    private var storage = [AnyCancellable]()

    init(octopus: OctopusSDK) {
        self.octopus = octopus

        octopus.core.configRepository.communityConfigPublisher
            .map { $0?.displayConfig }
            .sink { [unowned self] displayConfig in
                poweredByConfig = displayConfig?.poweredByOctopus ?? .normal
            }.store(in: &storage)
    }
}
