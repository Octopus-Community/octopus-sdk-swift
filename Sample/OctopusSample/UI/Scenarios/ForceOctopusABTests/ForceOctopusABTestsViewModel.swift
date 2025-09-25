//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus

/// View model of ForceOctopusABTestsView
class ForceOctopusABTestsViewModel: ObservableObject {
    @Published private(set) var octopus: OctopusSDK?
    @Published var error: Error?

    private var storage = [AnyCancellable]()

    private let octopusSDKProvider = OctopusSDKProvider.instance

    init() {
        octopusSDKProvider.$octopus
            .sink { [unowned self] in
                octopus = $0
            }.store(in: &storage)
    }

    func overrideCommunityAccess(enabled: Bool) {
        Task {
            do {
                try await octopus?.overrideCommunityAccess(enabled)
            } catch {
                self.error = error
            }
        }
    }
}
