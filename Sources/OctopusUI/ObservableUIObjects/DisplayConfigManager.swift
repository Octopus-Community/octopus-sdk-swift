//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus
import OctopusCore

@MainActor
final class DisplayConfigManager: ObservableObject {
    @Published private(set) var poweredByConfig: DisplayConfig.PoweredByOctopus = .normal

    private var storage = [AnyCancellable]()

    /// Designated init. Accepts the "powered by Octopus" publisher directly so previews/tests can
    /// inject a fixed value without requiring a full `OctopusSDK`.
    init(poweredByPublisher: AnyPublisher<DisplayConfig.PoweredByOctopus, Never>) {
        poweredByPublisher
            .sink { [unowned self] in poweredByConfig = $0 }
            .store(in: &storage)
    }

    /// Production convenience.
    convenience init(octopus: OctopusSDK) {
        self.init(poweredByPublisher:
            octopus.core.configRepository.communityConfigPublisher
                .map { $0?.displayConfig?.poweredByOctopus ?? .normal }
                .eraseToAnyPublisher())
    }

    /// Preview factory — emits `.normal` and never updates.
    static func forPreviews() -> DisplayConfigManager {
        DisplayConfigManager(poweredByPublisher: Just(.normal).eraseToAnyPublisher())
    }
}
