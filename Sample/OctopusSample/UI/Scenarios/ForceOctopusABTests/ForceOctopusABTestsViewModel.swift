//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Octopus

/// View model of ForceOctopusABTestsView
class ForceOctopusABTestsViewModel: ObservableObject {
    let octopus: OctopusSDK = OctopusSDKProvider.instance.octopus
    @Published var hasCommunityAccess = false
    @Published var error: Error?

    private var storage = [AnyCancellable]()

    private let octopusSDKProvider = OctopusSDKProvider.instance

    init() {
        hasCommunityAccess = octopus.hasAccessToCommunity

        octopus.$hasAccessToCommunity
            .sink { [unowned self] in
                hasCommunityAccess = $0
            }.store(in: &storage)
    }

    func overrideCommunityAccess(enabled: Bool) {
        Task {
            await overrideCommunityAccess(enabled: enabled)
        }
    }

    private func overrideCommunityAccess(enabled: Bool) async {
        do {
            try await octopus.overrideCommunityAccess(enabled)
        } catch {
            self.error = error
        }
    }
}
